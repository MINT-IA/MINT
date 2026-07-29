import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/routes/coach_chat_entry_payload.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:provider/provider.dart';

/// Tranche firstJob PR-E (E2) — contrat du CTA `firstjob-ask-coach` (RED-2).
///
/// RED-2 tombe quand le CTA `firstjob-ask-coach` EXISTE (noeud Semantics
/// tappable) sur /first-job et NAVIGUE vers /coach/chat en portant receiptId +
/// inputsHash (SPEC §1 T5 / §4.3). Le rendu verbatim de la valeur par le coach
/// et la parité A7 = PR-I (preuve sim), hors de ce test widget.

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

void main() {
  testWidgets(
      'RED-2: le CTA firstjob-ask-coach existe et navigue vers /coach/chat '
      'en portant receiptId + inputsHash', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 7000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Map<String, String>? capturedQuery;

    final router = GoRouter(
      initialLocation: '/first-job',
      routes: [
        GoRoute(
          path: '/first-job',
          builder: (context, state) =>
              ChangeNotifierProvider<CoachProfileProvider>.value(
            value: _FakeProvider(_completeProfile()),
            child: const FirstJobScreen(),
          ),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (context, state) {
            capturedQuery = state.uri.queryParameters;
            return const Scaffold(body: Text('coach-chat-landed'));
          },
        ),
      ],
    );

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

    // 1) Le CTA EXISTE (noeud Semantics tappable `firstjob-ask-coach`).
    expect(_bySemanticsId('firstjob-ask-coach'), findsOneWidget,
        reason: 'RED-2 : le CTA firstjob-ask-coach doit être monté sur /first-job');
    expect(find.text('Demander au coach'), findsOneWidget);

    // 2) Le tap NAVIGUE vers /coach/chat en portant receiptId + inputsHash.
    await tester.tap(find.text('Demander au coach'));
    await tester.pumpAndSettle();

    expect(find.text('coach-chat-landed'), findsOneWidget,
        reason: 'le CTA doit atterrir sur /coach/chat');
    expect(capturedQuery, isNotNull);
    expect(capturedQuery!['topic'], 'firstJobNet');
    final receiptId = capturedQuery!['receiptId'];
    final inputsHash = capturedQuery!['inputsHash'];
    expect(receiptId, isNotNull);
    expect(receiptId!.isNotEmpty, isTrue,
        reason: 'le handoff porte le receiptId du MoneyTruthReceipt émis');
    expect(inputsHash, isNotNull);
    expect(inputsHash!.length, 64,
        reason: 'inputsHash = SHA256 hex (64 car.) des inputs normalisés');
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(inputsHash), isTrue);
  });

  test(
      'coachChatEntryPayloadFromQuery porte receiptId + inputsHash (params '
      'reçus par le coach)', () {
    final payload = coachChatEntryPayloadFromQuery(
      {
        'topic': 'firstJobNet',
        'receiptId': 'rcpt-abc',
        'inputsHash': 'a' * 64,
      },
      debugMode: false,
    );
    expect(payload, isNotNull);
    expect(payload!.receiptId, 'rcpt-abc');
    expect(payload.inputsHash, 'a' * 64);
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
  });
}
