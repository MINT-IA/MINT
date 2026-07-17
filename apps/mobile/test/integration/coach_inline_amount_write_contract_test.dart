import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/chat_inline_inputs.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MemoryPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence {
  _MemoryPersistence(Map<String, dynamic> initial)
      : answers = Map<String, dynamic>.from(initial);

  Map<String, dynamic> answers;
  int saveAttempts = 0;
  int successfulSaves = 0;
  bool failNextSave = false;
  Completer<void>? nextSaveBarrier;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveAttempts++;
    final barrier = nextSaveBarrier;
    nextSaveBarrier = null;
    if (barrier != null) await barrier.future;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic persistence failure');
    }
    answers = Map<String, dynamic>.from(next);
    successfulSaves++;
  }
}

Map<String, dynamic> _baseAnswers({double periods = 12}) => <String, dynamic>{
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_nombre_mois': periods,
      'q_net_income_period_chf': 6500.0,
      'q_pay_frequency': 'monthly',
    };

Future<CoachProfileProvider> _loadedProvider(
  _MemoryPersistence persistence, {
  DateTime Function()? now,
}) async {
  final provider = CoachProfileProvider(
    taxProfilePersistence: persistence,
    now: now,
  );
  await provider.loadFromWizard();
  return provider;
}

void _expectUserInputProvenance(
  CoachProfile profile,
  String path,
  DateTime stamp,
) {
  expect(profile.dataSources[path], ProfileDataSource.userInput);
  expect(profile.dataTimestamps[path], stamp);
  expect(profile.dataSourceDates, contains(path));
  expect(profile.dataSourceDates[path], isNull);
}

Widget _coachApp(CoachProfileProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => MintStateProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
        home: CoachChatScreen(),
      ),
    );

Future<void> _pumpAskAmount(
  WidgetTester tester, {
  required CoachProfileProvider provider,
  required String field,
}) async {
  var responseCount = 0;
  CoachLlmService.registerOrchestrator(({
    required userMessage,
    required history,
    required ctx,
    byokConfig,
    memoryBlock,
    language = 'fr',
    cashLevel = 3,
  }) async {
    responseCount++;
    return CoachResponse(
      message: responseCount == 1 ? 'Renseigne ce montant.' : 'Valeur notée.',
      disclaimer: '',
      toolCalls: responseCount == 1
          ? <RagToolCall>[
              RagToolCall(
                name: 'ask_user_input',
                input: <String, dynamic>{
                  'field_key': field,
                  'prompt_text': 'Montant en CHF',
                },
              ),
            ]
          : const <RagToolCall>[],
    );
  });

  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(_coachApp(provider));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(find.byType(TextField), findsOneWidget);
  await tester.enterText(find.byType(TextField), 'question synthétique');
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 100));

  expect(find.byType(ChatAmountInput), findsOneWidget);
}

Future<void> _enterAndSubmitAmount(
  WidgetTester tester,
  String value, {
  int taps = 1,
}) async {
  final amount = find.byType(ChatAmountInput);
  final input = find.descendant(of: amount, matching: find.byType(TextField));
  final button =
      find.descendant(of: amount, matching: find.byType(FilledButton));
  await tester.enterText(input, value);
  for (var i = 0; i < taps; i++) {
    await tester.tap(button);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mint_coach_cash_level': 3,
    });
    FeatureFlags.enableSlmNarratives = false;
    FeatureFlags.typedLppEvidence = false;
  });

  tearDown(() {
    FeatureFlags.enableSlmNarratives = true;
    FeatureFlags.typedLppEvidence = false;
    CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
  });

  test('annual salary preserves the existing 12/13-period authority', () async {
    const annual = 120000.0;
    for (final periods in <double>[12, 13]) {
      final persistence = _MemoryPersistence(_baseAnswers(periods: periods));
      final provider = await _loadedProvider(persistence);

      expect(await provider.applySaveFact('incomeGrossYearly', annual), isTrue);
      expect(persistence.answers['q_gross_salary_annual'], annual);
      expect(persistence.answers['q_nombre_mois'], periods);
      expect(
        provider.profile!.salaireBrutMensuel,
        closeTo(annual / periods, 0.000001),
      );
    }
  });

  test('LPP and 3a writes remain total stocks and survive a cold reload',
      () async {
    final stamp = DateTime.utc(2026, 7, 17, 9, 30);
    final persistence = _MemoryPersistence(_baseAnswers());
    final provider = await _loadedProvider(persistence, now: () => stamp);
    var notifications = 0;
    provider.addListener(() => notifications++);

    expect(await provider.applySaveFact('avoirLpp', 70377.0), isTrue);
    expect(await provider.applySaveFact('pillar3aBalance', 32000.0), isTrue);

    expect(persistence.answers['_coach_avoir_lpp'], 70377.0);
    expect(persistence.answers, isNot(contains('_coach_avoir_lpp_oblig')));
    expect(persistence.answers, isNot(contains('_coach_avoir_lpp_suroblig')));
    expect(persistence.answers['q_3a_total'], 32000.0);
    expect(persistence.answers, isNot(contains('q_3a_annual_contribution')));
    expect(notifications, 2);

    final cold = await _loadedProvider(persistence, now: () => stamp);
    expect(cold.profile!.prevoyance.avoirLppTotal, 70377.0);
    expect(cold.profile!.prevoyance.totalEpargne3a, 32000.0);
    _expectUserInputProvenance(
      cold.profile!,
      'prevoyance.avoirLppTotal',
      stamp,
    );
    _expectUserInputProvenance(
      cold.profile!,
      'prevoyance.totalEpargne3a',
      stamp,
    );
  });

  test('zero is a durable known fact for all three canonical amounts',
      () async {
    const cases = <(String, String, String)>[
      ('incomeGrossYearly', 'q_gross_salary_annual', 'salaireBrutMensuel'),
      ('avoirLpp', '_coach_avoir_lpp', 'prevoyance.avoirLppTotal'),
      ('pillar3aBalance', 'q_3a_total', 'prevoyance.totalEpargne3a'),
    ];
    final stamp = DateTime.utc(2026, 7, 17, 10);

    for (final (canonicalKey, answerKey, provenancePath) in cases) {
      final persistence = _MemoryPersistence(_baseAnswers());
      final provider = await _loadedProvider(persistence, now: () => stamp);
      var notifications = 0;
      provider.addListener(() => notifications++);

      expect(await provider.applySaveFact(canonicalKey, 0.0), isTrue);
      expect(persistence.answers[answerKey], 0.0);
      expect(notifications, 1);

      final cold = await _loadedProvider(persistence, now: () => stamp);
      _expectUserInputProvenance(cold.profile!, provenancePath, stamp);
    }
  });

  test('negative and non-finite amounts fail before every side effect',
      () async {
    final outcomes = <bool>[];
    var totalAttempts = 0;
    var totalNotifications = 0;

    for (final canonicalKey in <String>[
      'incomeGrossYearly',
      'avoirLpp',
      'pillar3aBalance',
    ]) {
      for (final invalid in <double>[
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final persistence = _MemoryPersistence(_baseAnswers());
        final provider = await _loadedProvider(persistence);
        provider.addListener(() => totalNotifications++);
        outcomes.add(
          await provider.applySaveFact(canonicalKey, invalid),
        );
        totalAttempts += persistence.saveAttempts;
      }
    }

    expect(outcomes, everyElement(isFalse));
    expect(totalAttempts, 0);
    expect(totalNotifications, 0);
  });

  test(
      'typed LPP root presence rejects loose LPP before persistence even when unreadable',
      () async {
    FeatureFlags.typedLppEvidence = true;
    for (final strictRoot in <String>[
      'malformed-root',
      '{"schemaVersion":1,"self":null,"manualPartner":null,"legacyPartnerQuarantine":null}',
      '__secure__',
    ]) {
      final persistence = _MemoryPersistence(<String, dynamic>{
        ..._baseAnswers(),
        '_coach_lpp_evidence_v1': strictRoot,
      });
      final provider = await _loadedProvider(persistence);
      var notifications = 0;
      provider.addListener(() => notifications++);

      expect(await provider.applySaveFact('avoirLpp', 70377.0), isFalse);
      expect(persistence.saveAttempts, 0);
      expect(persistence.answers, isNot(contains('_coach_avoir_lpp')));
      expect(notifications, 0);
    }
  });

  for (final (field, canonicalKey, answerKey, amount) in const [
    ('salaireBrut', 'incomeGrossYearly', 'q_gross_salary_annual', '120000'),
    ('avoirLpp', 'avoirLpp', '_coach_avoir_lpp', '70377'),
    ('epargne3a', 'pillar3aBalance', 'q_3a_total', '32000'),
  ]) {
    testWidgets(
        'live $field callback awaits exactly one $canonicalKey write before answering',
        (tester) async {
      final persistence = _MemoryPersistence(_baseAnswers());
      final provider = await _loadedProvider(persistence);
      var notifications = 0;
      provider.addListener(() => notifications++);

      await _pumpAskAmount(tester, provider: provider, field: field);
      expect(find.byType(UserMessageBubble), findsOneWidget);
      await _enterAndSubmitAmount(tester, amount);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      expect(persistence.successfulSaves, 1);
      expect(persistence.answers[answerKey], double.parse(amount));
      expect(notifications, 1);
      expect(find.byType(ChatAmountInput), findsNothing);
      expect(find.byType(UserMessageBubble), findsNWidgets(2));
    });
  }

  testWidgets(
      'double tap stays saving and publishes only after the durable write',
      (tester) async {
    final persistence = _MemoryPersistence(_baseAnswers());
    final provider = await _loadedProvider(persistence);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final barrier = Completer<void>();
    persistence.nextSaveBarrier = barrier;

    await _pumpAskAmount(
      tester,
      provider: provider,
      field: 'salaireBrut',
    );
    await _enterAndSubmitAmount(tester, '120000', taps: 2);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ChatAmountInput), findsOneWidget);
    expect(find.byType(UserMessageBubble), findsOneWidget);
    expect(persistence.saveAttempts, 1);
    expect(persistence.successfulSaves, 0);
    expect(notifications, 0);

    barrier.complete();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));

    expect(persistence.saveAttempts, 1);
    expect(persistence.successfulSaves, 1);
    expect(notifications, 1);
    expect(find.byType(ChatAmountInput), findsNothing);
    expect(find.byType(UserMessageBubble), findsNWidgets(2));
  });

  testWidgets('failed save stays retryable and the retry commits exactly once',
      (tester) async {
    final persistence = _MemoryPersistence(_baseAnswers())..failNextSave = true;
    final provider = await _loadedProvider(persistence);
    var notifications = 0;
    provider.addListener(() => notifications++);

    await _pumpAskAmount(
      tester,
      provider: provider,
      field: 'epargne3a',
    );
    await _enterAndSubmitAmount(tester, '32000');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ChatAmountInput), findsOneWidget);
    expect(find.byType(UserMessageBubble), findsOneWidget);
    expect(persistence.saveAttempts, 1);
    expect(persistence.successfulSaves, 0);
    expect(notifications, 0);

    await _enterAndSubmitAmount(tester, '32000');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));

    expect(persistence.saveAttempts, 2);
    expect(persistence.successfulSaves, 1);
    expect(persistence.answers['q_3a_total'], 32000.0);
    expect(notifications, 1);
    expect(find.byType(ChatAmountInput), findsNothing);
    expect(find.byType(UserMessageBubble), findsNWidgets(2));
  });
}
