import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';
import 'package:provider/provider.dart';

final class _RecordingFrontierProvider extends CoachProfileProvider {
  _RecordingFrontierProvider(
    Map<String, dynamic> initialAnswers, {
    DateTime Function()? now,
  })  : _answers = Map<String, dynamic>.from(initialAnswers),
        _now = now ?? DateTime.now {
    _rebuild();
  }

  final Map<String, dynamic> _answers;
  final DateTime Function() _now;
  final List<Map<String, dynamic>> writes = <Map<String, dynamic>>[];
  CoachProfile? _current;

  @override
  CoachProfile? get profile => _current;

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    writes.add(Map<String, dynamic>.from(partial));
    for (final entry in partial.entries) {
      if (entry.value == null) {
        _answers.remove(entry.key);
      } else {
        _answers[entry.key] = entry.value;
      }
    }

    final provenance = Map<String, dynamic>.from(
      _answers['__provenance'] as Map? ?? const <String, dynamic>{},
    );
    const answerToPath = <String, String>{
      'q_residence_country': 'residenceCountry',
      'q_work_country': 'workCountry',
      'q_work_canton': 'workCanton',
    };
    for (final entry in partial.entries) {
      final path = answerToPath[entry.key];
      if (path == null) continue;
      if (entry.value == null) {
        provenance.remove(path);
      } else {
        provenance[path] = <String, dynamic>{
          'source': 'userInput',
          'updatedAt': _now().toIso8601String(),
          'sourceDate': _now().toIso8601String(),
        };
      }
    }
    _answers['__provenance'] = provenance;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    _current = CoachProfile.fromWizardAnswers(_answers, now: _now);
  }
}

Map<String, dynamic> _knownAnswers({
  String residenceCountry = 'FR',
  String workCountry = 'CH',
  String? workCanton = 'GE',
}) =>
    <String, dynamic>{
      'q_birth_year': 1985,
      'q_residence_country': residenceCountry,
      'q_work_country': workCountry,
      if (workCanton != null) 'q_work_canton': workCanton,
    };

Map<String, dynamic> _staleAnswers(DateTime now) {
  Map<String, dynamic> envelope(DateTime updatedAt) => <String, dynamic>{
        'source': 'userInput',
        'updatedAt': updatedAt.toIso8601String(),
        'sourceDate': updatedAt.toIso8601String(),
      };

  return <String, dynamic>{
    ..._knownAnswers(),
    '__provenance': <String, dynamic>{
      'residenceCountry': envelope(now.subtract(const Duration(days: 10))),
      'workCountry': envelope(now.subtract(const Duration(days: 10))),
      'workCanton': envelope(now.subtract(const Duration(days: 783))),
    },
  };
}

Future<GoRouter> _pumpScreen(
  WidgetTester tester,
  _RecordingFrontierProvider provider,
) async {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, __) => const FrontalierScreen()),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const Scaffold(
          body: Text('coach', key: Key('frontier_coach_destination')),
        ),
      ),
      GoRoute(
        path: '/fiscal',
        builder: (_, __) => const Scaffold(
          body: Text('fiscal', key: Key('frontier_fiscal_destination')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

DropdownButton<String> _dropdown(
  WidgetTester tester,
  String key,
) =>
    tester.widget<DropdownButton<String>>(
      find.byKey(Key(key)),
    );

void main() {
  testWidgets('missing jurisdiction collects and persists canonical facts',
      (tester) async {
    final provider = _RecordingFrontierProvider(<String, dynamic>{
      'q_birth_year': 1985,
      'q_residence_permit': 'G',
    });
    await _pumpScreen(tester, provider);

    expect(
      find.byKey(const Key('frontier_jurisdiction_missing_state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('frontier_jurisdiction_capture_cta')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('frontier_work_canton_field')),
      findsNothing,
    );

    _dropdown(tester, 'frontier_residence_country_field').onChanged!('FR');
    await tester.pumpAndSettle();
    expect(provider.writes.last, <String, dynamic>{
      'q_residence_country': 'FR',
    });

    _dropdown(tester, 'frontier_work_country_field').onChanged!('CH');
    await tester.pumpAndSettle();
    expect(provider.writes.last, <String, dynamic>{
      'q_work_country': 'CH',
    });
    expect(
      find.byKey(const Key('frontier_work_canton_field')),
      findsOneWidget,
    );

    _dropdown(tester, 'frontier_work_canton_field').onChanged!('GE');
    await tester.pumpAndSettle();
    expect(provider.writes.last, <String, dynamic>{
      'q_work_canton': 'GE',
    });
    expect(provider.profile!.residenceCountry!.value, 'FR');
    expect(provider.profile!.workCountry!.value, 'CH');
    expect(provider.profile!.workCanton!.value, 'GE');
    expect(
      find.byKey(const Key('frontier_jurisdiction_known_state')),
      findsOneWidget,
    );
  });

  testWidgets('changing work country outside CH atomically clears canton',
      (tester) async {
    final provider = _RecordingFrontierProvider(_knownAnswers());
    await _pumpScreen(tester, provider);

    _dropdown(tester, 'frontier_work_country_field').onChanged!('DE');
    await tester.pumpAndSettle();

    expect(provider.writes, hasLength(1));
    expect(provider.writes.single, <String, dynamic>{
      'q_work_country': 'DE',
      'q_work_canton': null,
    });
    expect(provider.profile!.workCanton, isNull);
    expect(
      find.byKey(const Key('frontier_work_canton_field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('frontier_jurisdiction_specialist_only_state')),
      findsOneWidget,
    );
  });

  testWidgets('stale canton shows the old fact and reconfirms in one gesture',
      (tester) async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final provider = _RecordingFrontierProvider(
      _staleAnswers(now),
      now: () => now,
    );
    await _pumpScreen(tester, provider);

    expect(
      find.byKey(const Key('frontier_jurisdiction_stale_state')),
      findsOneWidget,
    );
    expect(find.text('GE'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('frontier_jurisdiction_reconfirm_cta')),
    );
    await tester.pumpAndSettle();

    expect(provider.writes.single, <String, dynamic>{
      'q_work_canton': 'GE',
    });
    expect(
      find.byKey(const Key('frontier_jurisdiction_known_state')),
      findsOneWidget,
    );
  });

  testWidgets('FR CH GE stays educational with two separate control cards',
      (tester) async {
    final provider = _RecordingFrontierProvider(_knownAnswers());
    await _pumpScreen(tester, provider);

    expect(
      find.byKey(const Key('frontier_jurisdiction_known_state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('frontier_tax_orientation_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('frontier_social_insurance_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('frontier_specialist_questions_card')),
      findsOneWidget,
    );

    final visibleCopy = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ');
    expect(visibleCopy, contains('1966'));
    expect(visibleCopy, contains('candidat'));
    expect(visibleCopy, isNot(contains('CHF')));
    expect(visibleCopy, isNot(contains('Barème C')));
    expect(visibleCopy, isNot(contains('90 jours')));
  });

  testWidgets('1983 instrument remains only a candidate', (tester) async {
    final provider = _RecordingFrontierProvider(
      _knownAnswers(workCanton: 'VD'),
    );
    await _pumpScreen(tester, provider);

    final visibleCopy = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ');
    expect(visibleCopy, contains('1983'));
    expect(visibleCopy, contains('candidat'));
    expect(visibleCopy.toLowerCase(), isNot(contains('applicable')));
  });

  testWidgets('unsupported cross-border pair is specialist-only',
      (tester) async {
    final provider = _RecordingFrontierProvider(
      _knownAnswers(
        residenceCountry: 'CH',
        workCountry: 'FR',
        workCanton: null,
      ),
    );
    await _pumpScreen(tester, provider);

    expect(
      find.byKey(const Key('frontier_jurisdiction_specialist_only_state')),
      findsOneWidget,
    );
  });

  testWidgets('domestic state routes to the domestic fiscal journey',
      (tester) async {
    final provider = _RecordingFrontierProvider(
      _knownAnswers(residenceCountry: 'CH', workCountry: 'CH'),
    );
    await _pumpScreen(tester, provider);

    expect(
      find.byKey(const Key('frontier_jurisdiction_domestic_state')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('frontier_domestic_fiscal_cta')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('frontier_fiscal_destination')),
      findsOneWidget,
    );
  });

  testWidgets('missing capture CTA routes to coach', (tester) async {
    final provider = _RecordingFrontierProvider(<String, dynamic>{
      'q_birth_year': 1985,
    });
    await _pumpScreen(tester, provider);

    await tester.tap(
      find.byKey(const Key('frontier_jurisdiction_capture_cta')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('frontier_coach_destination')),
      findsOneWidget,
    );
  });
}
