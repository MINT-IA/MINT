import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/routes/coach_chat_entry_payload.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/money_truth_receipt_api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tranche firstJob PR-E (E2) — contrat du CTA `firstjob-ask-coach` (RED-2) +
/// double ceinture du handoff (Codex P1) : au tap, le receipt est POSTé au
/// store AVANT la nav, et l'URL porte receiptId + inputsHash + receiptInputs.
/// Le rendu verbatim par le coach et la parité sim A7 = PR-I.

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _completeProfile() => CoachProfile(
      birthYear: 2001, // âge 25 (fenêtre premier emploi)
      canton: 'VD',
      salaireBrutMensuel: 6500,
      userProvidedFields: const {'salary', 'age', 'canton'},
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2066),
        label: 'Retraite',
      ),
    );

/// Trouve un Semantics par son `identifier` (testID de l'arbre a11y).
Finder _bySemanticsId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

GoRouter _router({
  required MoneyTruthReceiptApiService receiptApi,
  required void Function(GoRouterState) onCoach,
}) =>
    GoRouter(
      initialLocation: '/first-job',
      routes: [
        GoRoute(
          path: '/first-job',
          builder: (context, state) =>
              ChangeNotifierProvider<CoachProfileProvider>.value(
            value: _FakeProvider(_completeProfile()),
            child: FirstJobScreen(receiptApi: receiptApi),
          ),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (context, state) {
            onCoach(state);
            return const Scaffold(body: Text('coach-chat-landed'));
          },
        ),
      ],
    );

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final mockStorage = <String, String>{};

  setUp(() {
    mockStorage.clear();
    AuthService.resetMemoryCacheForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final v = call.arguments['value'] as String?;
            if (v != null) mockStorage[call.arguments['key'] as String] = v;
            return null;
          case 'read':
            return mockStorage[call.arguments['key'] as String];
          case 'delete':
            mockStorage.remove(call.arguments['key'] as String);
            return null;
          case 'deleteAll':
            mockStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  testWidgets(
      'RED-2 + double ceinture : le CTA existe, POSTe le receipt au store, puis '
      'navigue vers /coach/chat avec receiptId + inputsHash + receiptInputs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 7000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

    // Ceinture 1 : mock du store — capture le POST déclenché par le tap.
    Map<String, dynamic>? storedBody;
    final receiptApi =
        MoneyTruthReceiptApiService(baseUrl: 'https://example.test');
    receiptApi.testClient = MockClient((http.Request request) async {
      storedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'status': 'stored',
          'receiptId': storedBody!['receipt']['receiptId'],
          'inputsHash': storedBody!['receipt']['inputsHash'],
        }),
        200,
      );
    });

    GoRouterState? coachState;
    await _pumpRouter(
      tester,
      _router(receiptApi: receiptApi, onCoach: (s) => coachState = s),
    );

    // 1) Le CTA EXISTE (noeud Semantics tappable `firstjob-ask-coach`).
    expect(_bySemanticsId('firstjob-ask-coach'), findsOneWidget,
        reason: 'RED-2 : le CTA firstjob-ask-coach doit être monté');
    expect(find.text('Demander au coach'), findsOneWidget);

    // 2) Le tap POSTe le receipt au store PUIS navigue.
    await tester.tap(find.text('Demander au coach'));
    await tester.pumpAndSettle();

    // Ceinture 1 : le store a bien reçu le receipt (net + provenance).
    expect(storedBody, isNotNull,
        reason: 'le CTA doit POSTer le receipt au store avant la nav');
    final storedReceipt = storedBody!['receipt'] as Map<String, dynamic>;
    expect(storedReceipt['claimId'], 'firstjob.net_salary.v1');
    expect(storedReceipt['base'], 'net');

    // Nav + ceinture 2 : receiptId + inputsHash + receiptInputs dans l'URL.
    expect(find.text('coach-chat-landed'), findsOneWidget);
    final query = coachState!.uri.queryParameters;
    expect(query['topic'], 'firstJobNet');
    expect(query['receiptId'], storedReceipt['receiptId']);
    final inputsHash = query['inputsHash'];
    expect(inputsHash!.length, 64);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(inputsHash), isTrue);
    final receiptInputs =
        jsonDecode(query['receiptInputs']!) as Map<String, dynamic>;
    expect(receiptInputs['canton'], 'VD');
    expect(receiptInputs.containsKey('salaireBrutMensuel'), isTrue);
    expect(receiptInputs.containsKey('age'), isTrue);
  });

  testWidgets('nav survit à un store échoué (best-effort, non bloquant)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 7000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

    // Store qui échoue (500) : la nav DOIT quand même avoir lieu.
    final receiptApi =
        MoneyTruthReceiptApiService(baseUrl: 'https://example.test');
    receiptApi.testClient =
        MockClient((r) async => http.Response('boom', 500));

    var landed = false;
    await _pumpRouter(
      tester,
      _router(receiptApi: receiptApi, onCoach: (_) => landed = true),
    );

    await tester.tap(find.text('Demander au coach'));
    await tester.pumpAndSettle();

    expect(landed, isTrue,
        reason: 'un store en échec ne doit PAS bloquer le handoff coach');
  });

  test(
      'coachChatEntryPayloadFromQuery porte receiptId + inputsHash + '
      'receiptInputs', () {
    final payload = coachChatEntryPayloadFromQuery(
      {
        'topic': 'firstJobNet',
        'receiptId': 'rcpt-abc',
        'inputsHash': 'a' * 64,
        'receiptInputs': jsonEncode({'salaireBrutMensuel': 6788.0, 'age': 30}),
      },
      debugMode: false,
    );
    expect(payload, isNotNull);
    expect(payload!.receiptId, 'rcpt-abc');
    expect(payload.inputsHash, 'a' * 64);
    expect(payload.receiptInputs, {'salaireBrutMensuel': 6788.0, 'age': 30});
    expect(payload.topic, 'firstJobNet');
  });

  test('coachChatEntryPayloadFromQuery: pas de receipt hors handoff', () {
    final payload = coachChatEntryPayloadFromQuery(
      {'topic': 'budget'},
      debugMode: false,
    );
    expect(payload, isNotNull);
    expect(payload!.receiptId, isNull);
    expect(payload.inputsHash, isNull);
    expect(payload.receiptInputs, isNull);
  });
}
