import 'dart:ui' show SemanticsAction;

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
  final List<Map<String, dynamic>> attempts = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> writes = <Map<String, dynamic>>[];
  CoachProfile? _current;
  int failuresRemaining = 0;

  @override
  CoachProfile? get profile => _current;

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    final snapshot = Map<String, dynamic>.from(partial);
    attempts.add(snapshot);
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('synthetic frontier persistence failure');
    }
    writes.add(snapshot);
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
    initialLocation: '/segments/frontalier',
    routes: <RouteBase>[
      GoRoute(
        path: '/segments/frontalier',
        builder: (_, __) => const FrontalierScreen(),
      ),
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

Future<void> _selectDropdownValueByTap(
  WidgetTester tester, {
  required String fieldKey,
  required String value,
  bool settleAfterSelection = true,
}) async {
  final field = find.byKey(Key(fieldKey));
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();

  final option = find
      .byWidgetPredicate(
        (widget) => widget is DropdownMenuItem<String> && widget.value == value,
        description: 'DropdownMenuItem<String> value=$value',
      )
      .last;
  expect(option, findsOneWidget);
  final tappable = find.ancestor(
    of: option,
    matching: find.byType(InkWell),
  );
  expect(tappable, findsOneWidget);
  await tester.tap(tappable);
  if (settleAfterSelection) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

enum _FrontierFailureKind { residence, workCountry, workCanton, reconfirm }

final class _FrontierFailureCase {
  const _FrontierFailureCase({
    required this.name,
    required this.kind,
    required this.expectedAttempt,
    this.fieldKey,
    this.value,
  });

  final String name;
  final _FrontierFailureKind kind;
  final String? fieldKey;
  final String? value;
  final Map<String, dynamic> expectedAttempt;
}

const _failureCases = <_FrontierFailureCase>[
  _FrontierFailureCase(
    name: 'residence country',
    kind: _FrontierFailureKind.residence,
    fieldKey: 'frontier_residence_country_field',
    value: 'DE',
    expectedAttempt: <String, dynamic>{'q_residence_country': 'DE'},
  ),
  _FrontierFailureCase(
    name: 'work country',
    kind: _FrontierFailureKind.workCountry,
    fieldKey: 'frontier_work_country_field',
    value: 'DE',
    expectedAttempt: <String, dynamic>{
      'q_work_country': 'DE',
      'q_work_canton': null,
    },
  ),
  _FrontierFailureCase(
    name: 'work canton',
    kind: _FrontierFailureKind.workCanton,
    fieldKey: 'frontier_work_canton_field',
    value: 'ZH',
    expectedAttempt: <String, dynamic>{'q_work_canton': 'ZH'},
  ),
  _FrontierFailureCase(
    name: 'stale reconfirmation',
    kind: _FrontierFailureKind.reconfirm,
    expectedAttempt: <String, dynamic>{'q_work_canton': 'GE'},
  ),
];

void _expectFrChGeProfile(_RecordingFrontierProvider provider) {
  expect(provider.profile!.residenceCountry!.value, 'FR');
  expect(provider.profile!.workCountry!.value, 'CH');
  expect(provider.profile!.workCanton!.value, 'GE');
}

void main() {
  testWidgets('real jurisdiction dropdowns expose actionable native ids',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final provider = _RecordingFrontierProvider(_knownAnswers());
      await _pumpScreen(tester, provider);

      final nodeIds = <int>{};
      for (final identifier in <String>[
        'frontier_residence_country_field',
        'frontier_work_country_field',
        'frontier_work_canton_field',
      ]) {
        final action = find.bySemanticsIdentifier(identifier);
        final dropdown = find.descendant(
          of: action,
          matching: find.byType(DropdownButton<String>),
        );
        expect(action, findsOneWidget, reason: identifier);
        expect(dropdown, findsOneWidget, reason: identifier);
        final actionNode = tester.getSemantics(action);
        expect(
          actionNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: identifier,
        );
        expect(
          actionNode.getSemanticsData().flagsCollection.isButton,
          isTrue,
          reason: identifier,
        );
        expect(
          actionNode.id,
          tester.getSemantics(dropdown).id,
          reason: identifier,
        );
        nodeIds.add(actionNode.id);
      }
      expect(nodeIds, hasLength(3));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('FR CH GE known state exposes its native runtime id',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final provider = _RecordingFrontierProvider(_knownAnswers());
      await _pumpScreen(tester, provider);

      expect(
        find.bySemanticsIdentifier('frontier_jurisdiction_known_state'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('frontier_jurisdiction_known_state')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'real dropdown taps persist canonical facts without changing route',
      (tester) async {
    final now = DateTime.utc(2026, 7, 19, 12);
    final provider = _RecordingFrontierProvider(
      <String, dynamic>{'q_birth_year': 1985},
      now: () => now,
    );
    final router = await _pumpScreen(tester, provider);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/segments/frontalier',
    );

    await _selectDropdownValueByTap(
      tester,
      fieldKey: 'frontier_residence_country_field',
      value: 'FR',
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/segments/frontalier',
    );

    await _selectDropdownValueByTap(
      tester,
      fieldKey: 'frontier_work_country_field',
      value: 'CH',
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/segments/frontalier',
    );

    await _selectDropdownValueByTap(
      tester,
      fieldKey: 'frontier_work_canton_field',
      value: 'GE',
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/segments/frontalier',
    );

    final expectedMutations = <Map<String, dynamic>>[
      <String, dynamic>{'q_residence_country': 'FR'},
      <String, dynamic>{'q_work_country': 'CH'},
      <String, dynamic>{'q_work_canton': 'GE'},
    ];
    expect(provider.attempts, expectedMutations);
    expect(provider.writes, expectedMutations);
    _expectFrChGeProfile(provider);
    for (final field in <String>[
      'residenceCountry',
      'workCountry',
      'workCanton',
    ]) {
      expect(provider.profile!.dataSources[field], ProfileDataSource.userInput);
      expect(provider.profile!.dataTimestamps[field], now);
      expect(provider.profile!.dataSourceDates[field], now);
    }
    expect(
      find.byKey(const Key('frontier_jurisdiction_known_state')),
      findsOneWidget,
    );
  });

  for (final failureCase in _failureCases) {
    testWidgets(
        '${failureCase.name} failure is absorbed without route or profile drift',
        (tester) async {
      final now = DateTime.utc(2026, 7, 19, 12);
      final provider = _RecordingFrontierProvider(
        failureCase.kind == _FrontierFailureKind.reconfirm
            ? _staleAnswers(now)
            : _knownAnswers(),
        now: () => now,
      );
      final router = await _pumpScreen(tester, provider);
      provider.failuresRemaining = 1;

      if (failureCase.kind == _FrontierFailureKind.reconfirm) {
        await tester.tap(
          find.byKey(const Key('frontier_jurisdiction_reconfirm_cta')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await _selectDropdownValueByTap(
          tester,
          fieldKey: failureCase.fieldKey!,
          value: failureCase.value!,
          settleAfterSelection: false,
        );
      }
      final uncaughtPersistenceError = tester.takeException();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/segments/frontalier',
      );
      expect(provider.attempts, <Map<String, dynamic>>[
        failureCase.expectedAttempt,
      ]);
      expect(provider.writes, isEmpty);
      _expectFrChGeProfile(provider);
      expect(
        uncaughtPersistenceError,
        isNull,
        reason: 'the inline writer must absorb persistence failure',
      );
    });
  }

  testWidgets('missing jurisdiction collects and persists canonical facts',
      (tester) async {
    final provider = _RecordingFrontierProvider(<String, dynamic>{
      'q_birth_year': 1985,
      'q_residence_permit': 'G',
    });
    final router = await _pumpScreen(tester, provider);

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

    await _selectDropdownValueByTap(
      tester,
      fieldKey: 'frontier_residence_country_field',
      value: 'FR',
    );
    expect(provider.writes.last, <String, dynamic>{
      'q_residence_country': 'FR',
    });

    await _selectDropdownValueByTap(
      tester,
      fieldKey: 'frontier_work_country_field',
      value: 'CH',
    );
    expect(provider.writes.last, <String, dynamic>{
      'q_work_country': 'CH',
    });
    expect(
      find.byKey(const Key('frontier_work_canton_field')),
      findsOneWidget,
    );

    await _selectDropdownValueByTap(
      tester,
      fieldKey: 'frontier_work_canton_field',
      value: 'GE',
    );
    expect(provider.writes.last, <String, dynamic>{
      'q_work_canton': 'GE',
    });
    expect(provider.attempts, provider.writes);
    _expectFrChGeProfile(provider);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/segments/frontalier',
    );
    expect(
      find.byKey(const Key('frontier_jurisdiction_known_state')),
      findsOneWidget,
    );
  });

  testWidgets('changing work country outside CH atomically clears canton',
      (tester) async {
    final provider = _RecordingFrontierProvider(_knownAnswers());
    final router = await _pumpScreen(tester, provider);

    await _selectDropdownValueByTap(
      tester,
      fieldKey: 'frontier_work_country_field',
      value: 'DE',
    );

    expect(provider.attempts, hasLength(1));
    expect(provider.attempts.single, <String, dynamic>{
      'q_work_country': 'DE',
      'q_work_canton': null,
    });
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
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/segments/frontalier',
    );
  });

  testWidgets('stale canton shows the old fact and reconfirms in one gesture',
      (tester) async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final provider = _RecordingFrontierProvider(
      _staleAnswers(now),
      now: () => now,
    );
    final router = await _pumpScreen(tester, provider);

    expect(
      find.byKey(const Key('frontier_jurisdiction_stale_state')),
      findsOneWidget,
    );
    expect(find.text('GE'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('frontier_jurisdiction_reconfirm_cta')),
    );
    await tester.pumpAndSettle();

    const reconfirmation = <String, dynamic>{
      'q_work_canton': 'GE',
    };
    expect(provider.attempts.single, reconfirmation);
    expect(provider.writes.single, reconfirmation);
    _expectFrChGeProfile(provider);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/segments/frontalier',
    );
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
