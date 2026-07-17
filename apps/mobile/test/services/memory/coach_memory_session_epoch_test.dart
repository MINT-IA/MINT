import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CoachMemoryService.debugResetSessionAuthority();
  });

  tearDown(CoachMemoryService.debugResetSessionAuthority);

  test('save captures one identity and keeps one namespace to completion',
      () async {
    final epoch = SessionEpoch();
    var identityReads = 0;
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () async => identityReads++ == 0 ? 'user-a' : 'user-b',
    );
    final prefs = await SharedPreferences.getInstance();

    await CoachMemoryService.saveInsight(
      _insight('one'),
      prefs: prefs,
      transport: _ControlledTransport(hasCredential: false),
    );

    expect(identityReads, 1);
    expect(prefs.containsKey('_coach_insights_user-a'), isTrue);
    expect(prefs.containsKey('_coach_insights_user-b'), isFalse);
  });

  test('delayed account A save cannot publish after logout and login B',
      () async {
    final epoch = SessionEpoch();
    final identityGate = Completer<String?>();
    final identityStarted = Completer<void>();
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () {
        identityStarted.complete();
        return identityGate.future;
      },
    );
    final prefs = await SharedPreferences.getInstance();

    final staleSave = CoachMemoryService.saveInsight(
      _insight('from-a'),
      prefs: prefs,
      transport: _ControlledTransport(hasCredential: false),
    );
    await identityStarted.future;
    epoch.beginTermination();
    await CoachMemoryService.clearForSessionTermination(prefs: prefs);
    epoch.completeTermination();
    identityGate.complete('user-a');

    await expectLater(staleSave, throwsA(isA<SessionEpochInvalidated>()));
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () async => 'user-b',
    );
    await CoachMemoryService.saveInsight(
      _insight('from-b'),
      prefs: prefs,
      transport: _ControlledTransport(hasCredential: false),
    );

    expect(prefs.containsKey('_coach_insights_user-a'), isFalse);
    final b = await CoachMemoryService.getInsights(prefs: prefs);
    expect(b.map((insight) => insight.id), ['from-b']);
  });

  test('delayed A sync cannot become a B request or resurrect local data',
      () async {
    final epoch = SessionEpoch();
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () async => 'user-a',
    );
    final prefs = await SharedPreferences.getInstance();
    final credentialGate = Completer<bool>();
    final credentialStarted = Completer<void>();
    final transport = _ControlledTransport(
      credentialFuture: () {
        if (!credentialStarted.isCompleted) credentialStarted.complete();
        return credentialGate.future;
      },
    );

    await CoachMemoryService.saveInsight(
      _insight('from-a'),
      prefs: prefs,
      transport: transport,
    );
    await credentialStarted.future;
    epoch.beginTermination();
    await CoachMemoryService.clearForSessionTermination(prefs: prefs);
    epoch.completeTermination();
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () async => 'user-b',
    );
    credentialGate.complete(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(transport.requests, isEmpty);
    expect(prefs.containsKey('_coach_insights_user-a'), isFalse);
    expect(prefs.containsKey('_coach_insights_user-b'), isFalse);
  });

  test('cold delayed A read is rejected instead of publishing into B',
      () async {
    final epoch = SessionEpoch();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '_coach_insights_user-a',
      CoachInsight.encodeList([_insight('from-a')]),
    );
    final identityGate = Completer<String?>();
    final identityStarted = Completer<void>();
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () {
        identityStarted.complete();
        return identityGate.future;
      },
    );

    final staleRead = CoachMemoryService.getInsights(prefs: prefs);
    await identityStarted.future;
    epoch.beginTermination();
    await CoachMemoryService.clearForSessionTermination(prefs: prefs);
    epoch.completeTermination();
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () async => 'user-b',
    );
    identityGate.complete('user-a');

    await expectLater(staleRead, throwsA(isA<SessionEpochInvalidated>()));
    expect(await CoachMemoryService.getInsights(prefs: prefs), isEmpty);
  });

  test('event save captures identity once for read and write', () async {
    final epoch = SessionEpoch();
    var identityReads = 0;
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: epoch,
      userIdReader: () async => identityReads++ == 0 ? 'user-a' : 'user-b',
    );
    final prefs = await SharedPreferences.getInstance();

    await CoachMemoryService.saveEvent(
      'lpp',
      'Certificat synthétique',
      date: DateTime(2026, 7, 17, 12),
      prefs: prefs,
    );

    expect(identityReads, 1);
    expect(prefs.containsKey('_coach_events_user-a'), isTrue);
    expect(prefs.containsKey('_coach_events_user-b'), isFalse);
  });

  test('identity lookup failure makes save fail closed without anon write',
      () async {
    final prefs = await SharedPreferences.getInstance();
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: SessionEpoch(),
      userIdReader: () async => throw StateError('synthetic keychain failure'),
    );

    await expectLater(
      CoachMemoryService.saveInsight(
        _insight('must-not-save'),
        prefs: prefs,
        transport: _ControlledTransport(hasCredential: false),
      ),
      throwsStateError,
    );

    expect(prefs.containsKey('_coach_insights___anon'), isFalse);
  });

  test('only a successful null identity may select the anon namespace',
      () async {
    final prefs = await SharedPreferences.getInstance();
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: SessionEpoch(),
      userIdReader: () async => '   ',
    );

    await expectLater(
      CoachMemoryService.saveInsight(
        _insight('must-not-save'),
        prefs: prefs,
        transport: _ControlledTransport(hasCredential: false),
      ),
      throwsStateError,
    );

    expect(prefs.containsKey('_coach_insights___anon'), isFalse);
  });

  test('identity lookup failure makes read fail closed without anon fallback',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '_coach_insights___anon',
      CoachInsight.encodeList([_insight('anonymous-existing')]),
    );
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: SessionEpoch(),
      userIdReader: () async => throw StateError('synthetic keychain failure'),
    );

    await expectLater(
      CoachMemoryService.getInsights(prefs: prefs),
      throwsStateError,
    );

    expect(prefs.containsKey('_coach_insights___anon'), isTrue);
  });

  test(
      'identity lookup failure makes clear fail closed and preserves anon data',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '_coach_insights___anon',
      CoachInsight.encodeList([_insight('anonymous-existing')]),
    );
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: SessionEpoch(),
      userIdReader: () async => throw StateError('synthetic keychain failure'),
    );

    await expectLater(
      CoachMemoryService.clear(prefs: prefs),
      throwsStateError,
    );

    expect(prefs.containsKey('_coach_insights___anon'), isTrue);
  });

  test(
      'corrupt auth authority blocks every CoachMemory operation without anon access',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final anonInsights = CoachInsight.encodeList([_insight('anon-existing')]);
    final anonEvents = CoachInsight.encodeList([
      CoachInsight(
        id: 'anon-event',
        createdAt: DateTime.utc(2026, 7, 17),
        topic: 'lpp',
        summary: 'Événement anonyme existant',
        type: InsightType.event,
      ),
    ]);
    await prefs.setString('_coach_insights___anon', anonInsights);
    await prefs.setString('_coach_events___anon', anonEvents);
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'auth_session_v1', value: '{broken');
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: SessionEpoch(),
      userIdReader: AuthService.getUserId,
    );

    final operations = <Future<void> Function()>[
      () => CoachMemoryService.saveInsight(
            _insight('must-not-save'),
            prefs: prefs,
            transport: _ControlledTransport(hasCredential: false),
          ),
      () async {
        await CoachMemoryService.getInsights(prefs: prefs);
      },
      () => CoachMemoryService.saveEvent(
            'lpp',
            'Must not save',
            prefs: prefs,
          ),
      () => CoachMemoryService.clear(prefs: prefs),
    ];

    for (final operation in operations) {
      await expectLater(operation(), throwsA(_authRecoveryRequired));
    }

    expect(prefs.getString('_coach_insights___anon'), anonInsights);
    expect(prefs.getString('_coach_events___anon'), anonEvents);
    expect(
      await secureStorage.read(key: 'auth_session_recovery_required_v1'),
      '1',
    );
  });
}

CoachInsight _insight(String id) => CoachInsight(
      id: id,
      createdAt: DateTime.utc(2026, 7, 17),
      topic: 'lpp',
      summary: 'Résumé synthétique',
      type: InsightType.fact,
    );

final class _ControlledTransport implements AuthenticatedTransport {
  _ControlledTransport({
    this.hasCredential = true,
    this.credentialFuture,
  });

  final bool hasCredential;
  final Future<bool> Function()? credentialFuture;
  final List<AuthenticatedRequest> requests = [];

  @override
  AuthenticatedOperation beginOperation() => _ControlledOperation(this);
}

final class _ControlledOperation implements AuthenticatedOperation {
  _ControlledOperation(this.transport);

  final _ControlledTransport transport;
  bool _authorized = false;

  @override
  Future<void> requireSession() async {
    final authorized = await (transport.credentialFuture?.call() ??
        Future<bool>.value(transport.hasCredential));
    if (!authorized) throw ApiException.authenticationRequired();
    _authorized = true;
  }

  @override
  Future<AuthenticatedResponse> send(AuthenticatedRequest request) async {
    if (!_authorized) await requireSession();
    transport.requests.add(request);
    return AuthenticatedResponse(
      statusCode: 200,
      body: '{}',
      bodyBytes: const [123, 125],
      headers: const {'content-type': 'application/json'},
    );
  }
}

final Matcher _authRecoveryRequired = predicate<Object>(
  (error) => error.runtimeType.toString() == 'AuthSessionRecoveryRequired',
  'AuthSessionRecoveryRequired',
);
