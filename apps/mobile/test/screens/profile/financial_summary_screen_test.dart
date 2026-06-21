import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);

  final CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;
}

Widget _pumpable(
  CoachProfile? profile, {
  Future<List<Object>> Function()? restartDiagnosticResetOverride,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: _FakeCoachProfileProvider(profile),
      ),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: FinancialSummaryScreen(
        restartDiagnosticResetOverride: restartDiagnosticResetOverride,
      ),
    ),
  );
}

Widget _pumpableWithRouter(
  CoachProfile? profile, {
  Future<List<Object>> Function()? restartDiagnosticResetOverride,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => FinancialSummaryScreen(
          restartDiagnosticResetOverride: restartDiagnosticResetOverride,
        ),
      ),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const Scaffold(
          body: SizedBox(key: ValueKey('coach_route_after_reset')),
        ),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: _FakeCoachProfileProvider(profile),
      ),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ],
    child: MaterialApp.router(
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
}

CoachProfile _defensibleFinancialProfile() {
  final answers = CoachProfileSeeds.registry['julien_swiss']!.toWizardAnswers(
    now: DateTime(2026, 6, 4),
  );
  answers['_coach_avoir_lpp'] = 50000.0;
  answers['_coach_avs_rente_estimee'] = 1200.0;
  return CoachProfile.fromWizardAnswers(answers);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorage = <String, String>{};

  setUp(() {
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      secureStorageChannel,
      (call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) {
              secureStorage[key] = value;
            }
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key != null) {
              secureStorage.remove(key);
            }
            return null;
          case 'deleteAll':
            secureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('empty material profile shows diagnostic state, not covered gap',
      (tester) async {
    await tester.pumpWidget(_pumpable(CoachProfile.fromWizardAnswers({})));
    await tester.pumpAndSettle();

    expect(find.text('Aucun profil renseigné'), findsOneWidget);
    expect(find.text('Commencer le diagnostic'), findsOneWidget);
    expect(find.text('Tu es bien couvert·e'), findsNothing);
  });

  testWidgets(
      'income-only restored profile stays neutral without CHF projection',
      (tester) async {
    final profile = CoachProfile.fromWizardAnswers({
      'q_date_of_birth': '1981-06-15',
      'q_canton': 'VD',
      'q_gross_salary_annual': 120000.0,
    });

    await tester.pumpWidget(_pumpable(profile));
    await tester.pumpAndSettle();

    expect(find.text('Complète ton profil pour voir tes chiffres'),
        findsOneWidget);
    expect(find.text('Commencer le diagnostic'), findsOneWidget);
    expect(find.text('À la retraite, il te manquera'), findsNothing);
    expect(find.text('Tu es bien couvert·e'), findsNothing);
    expect(find.textContaining('CHF'), findsNothing);
  });

  testWidgets(
      'expense-complete profile stays neutral until pension sources are real',
      (tester) async {
    final profile = CoachProfile.fromWizardAnswers({
      'q_date_of_birth': '1981-06-15',
      'q_canton': 'VD',
      'q_gross_salary_annual': 120000.0,
      'q_housing_cost_period_chf': 2800.0,
      'q_lamal_premium_monthly_chf': 430.0,
      'q_cash_total': 25000.0,
      'q_has_consumer_debt': false,
    });

    await tester.pumpWidget(_pumpable(profile));
    await tester.pumpAndSettle();

    expect(find.text('Complète ton profil pour voir tes chiffres'),
        findsOneWidget);
    expect(find.text('À la retraite, il te manquera'), findsNothing);
    expect(find.text('Tu es bien couvert·e'), findsNothing);
    expect(find.textContaining('CHF'), findsNothing);
  });

  testWidgets('material profile leads with dossier facts before projection',
      (tester) async {
    tester.view.physicalSize = const Size(368, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final profile = _defensibleFinancialProfile();

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
    final profile = _defensibleFinancialProfile();

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

  testWidgets(
      'restart diagnostic clears active coach conversations before entering chat',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ConversationStore.setCurrentUserId('user-42');
    final store = ConversationStore();
    await store.saveConversation('stale-conversation', [
      ChatMessage(
        role: 'user',
        content: 'ancien contexte',
        timestamp: DateTime(2026, 6, 13, 9),
      ),
    ]);
    expect(await store.listConversations(), hasLength(1));

    tester.view.physicalSize = const Size(368, 3400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      ConversationStore.setCurrentUserId(null);
    });

    final profile = _defensibleFinancialProfile();

    await tester.pumpWidget(_pumpableWithRouter(profile));
    await tester.pumpAndSettle();

    final restartButton =
        find.byKey(const ValueKey('financial_summary_restart_diagnostic'));
    await tester.tap(restartButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    ConversationStore.setCurrentUserId('user-42');
    expect(await store.listConversations(), isEmpty);
    expect(
        find.byKey(const ValueKey('coach_route_after_reset')), findsOneWidget);
  });

  test('restart diagnostic reset keeps running after one operation fails',
      () async {
    final calls = <String>[];

    final failures = await FinancialSummaryScreen.runBestEffortResetForTest([
      () async {
        calls.add('first');
        throw StateError('first failed');
      },
      () async {
        calls.add('second');
      },
      () async {
        calls.add('third');
        throw StateError('third failed');
      },
    ]);

    expect(calls, ['first', 'second', 'third']);
    expect(failures, hasLength(2));
  });

  test('restart diagnostic skips profile clear when persistent purge fails',
      () async {
    final calls = <String>[];

    final failures =
        await FinancialSummaryScreen.runPersistentResetThenProfileClearForTest(
      persistentOperations: [
        () async {
          calls.add('conversation');
        },
        () async {
          calls.add('memory');
          throw StateError('memory failed');
        },
      ],
      profileClear: () async {
        calls.add('profile-clear');
      },
    );

    expect(calls, ['conversation', 'memory']);
    expect(failures, hasLength(1));
  });

  test('restart diagnostic clears profile after persistent purges succeed',
      () async {
    final calls = <String>[];

    final failures =
        await FinancialSummaryScreen.runPersistentResetThenProfileClearForTest(
      persistentOperations: [
        () async {
          calls.add('conversation');
        },
        () async {
          calls.add('memory');
        },
      ],
      profileClear: () async {
        calls.add('profile-clear');
      },
    );

    expect(calls, ['conversation', 'memory', 'profile-clear']);
    expect(failures, isEmpty);
  });

  testWidgets('restart diagnostic stays put and shows error on partial reset',
      (tester) async {
    tester.view.physicalSize = const Size(368, 3400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final profile = _defensibleFinancialProfile();

    await tester.pumpWidget(
      _pumpableWithRouter(
        profile,
        restartDiagnosticResetOverride: () async => [StateError('boom')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('financial_summary_restart_diagnostic')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('coach_route_after_reset')),
      findsNothing,
    );
    expect(
      find.text(
        'Une partie des données locales n’a pas pu être effacée. Réessaie dans un instant.',
      ),
      findsOneWidget,
    );
  });
}
