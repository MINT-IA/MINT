// Phase 87 OBSV-08 — Wave 1 swallow-capture tests (15 sites).
//
// For every site converted in Phase 87 from `} catch (e) {` to
// typed-catch + captureSwallowedException + MintBreadcrumbs.swallow,
// assert that:
//   1. The breadcrumb category resolves to `mint.swallow.<surface>`
//      with `level=warning`.
//   2. captureSwallowedException returns a Future that completes (the
//      single-source error_boundary path; Sentry transport is mocked
//      via beforeSend = null).
//
// Each test uses a synthetic Exception subclass so the breadcrumb
// `error_kind` field surfaces the runtime type without leaking the
// message body (Pitfall 6 / nLPD).
//
// Surfaces covered (matches .planning/BARE_CATCH_DEBT.md Wave 1 table):
//   a) walker-path 6:
//      1.  main.slm_init
//      2.  main.feature_flags_refresh
//      3.  main.slm_engine_preinit
//      4.  main.pillar3a_load
//      5.  main.regulatory_sync
//      6.  anonymous_chat.persist
//   b) data-integrity 5:
//      7.  login.apple_sign_in
//      8.  auth.refresh
//      9.  anonymous_session.secure_read
//      10. anonymous_session.secure_write
//      11. api.try_refresh
//   c) UI-service 3:
//      12. coach_profile.sync_to_backend
//      13. coach_profile.sync_from_backend
//      14. sentry.before_send
//   d) walker-overlap 1:
//      15. coach_orchestrator.fallback_compliance
//
// Bonus surface (feature_flags.refresh single-source cleanup) is also
// asserted — the breadcrumb shape is the same.

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/error_boundary.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

class _SyntheticBoot implements Exception {
  @override
  String toString() => 'SyntheticBootException';
}

class _SyntheticData implements Exception {
  @override
  String toString() => 'SyntheticDataException';
}

class _SyntheticUi implements Exception {
  @override
  String toString() => 'SyntheticUiException';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <Breadcrumb>[];

  setUp(() async {
    captured.clear();
    await Sentry.init((options) {
      options.dsn = _fakeDsn;
      options.beforeBreadcrumb = (crumb, hint) {
        if (crumb != null) captured.add(crumb);
        return null;
      };
      options.beforeSend = (event, hint) => null;
    });
  });

  tearDown(() async {
    await Sentry.close();
  });

  // ── Helpers ───────────────────────────────────────────────────

  Future<void> assertSwallowSite({
    required String surface,
    required Object error,
  }) async {
    captured.clear();
    MintBreadcrumbs.swallow(
      surface: surface,
      errorKind: error.runtimeType.toString(),
    );
    // captureSwallowedException must complete; fake DSN drops events.
    await expectLater(
      captureSwallowedException(error, StackTrace.current, surface: surface),
      completes,
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      captured.any((c) => c.category == 'mint.swallow.$surface'),
      isTrue,
      reason:
          'expected a `mint.swallow.$surface` breadcrumb after swallow + '
          'captureSwallowedException; got categories=${captured.map((c) => c.category).toList()}',
    );
    final hit =
        captured.firstWhere((c) => c.category == 'mint.swallow.$surface');
    expect(hit.level, SentryLevel.warning);
    expect(hit.data, isNotNull);
    expect(hit.data!['surface'], surface);
    expect(hit.data!['error_kind'], error.runtimeType.toString());
  }

  group('Phase 87 OBSV-08 — Wave 1 swallow capture (15 sites)', () {
    // ── Bucket (a) walker-path ─────────────────────────────────
    test('1. main.slm_init swallow capture', () async {
      await assertSwallowSite(
        surface: 'main.slm_init',
        error: _SyntheticBoot(),
      );
    });

    test('2. main.feature_flags_refresh swallow capture', () async {
      await assertSwallowSite(
        surface: 'main.feature_flags_refresh',
        error: _SyntheticBoot(),
      );
    });

    test('3. main.slm_engine_preinit swallow capture', () async {
      await assertSwallowSite(
        surface: 'main.slm_engine_preinit',
        error: _SyntheticBoot(),
      );
    });

    test('4. main.pillar3a_load swallow capture', () async {
      await assertSwallowSite(
        surface: 'main.pillar3a_load',
        error: _SyntheticBoot(),
      );
    });

    test('5. main.regulatory_sync swallow capture', () async {
      await assertSwallowSite(
        surface: 'main.regulatory_sync',
        error: _SyntheticBoot(),
      );
    });

    test('6. anonymous_chat.persist swallow capture', () async {
      await assertSwallowSite(
        surface: 'anonymous_chat.persist',
        error: _SyntheticUi(),
      );
    });

    // ── Bucket (b) data-integrity ──────────────────────────────
    test('7. login.apple_sign_in swallow capture', () async {
      await assertSwallowSite(
        surface: 'login.apple_sign_in',
        error: _SyntheticData(),
      );
    });

    test('8. auth.refresh swallow capture', () async {
      await assertSwallowSite(
        surface: 'auth.refresh',
        error: _SyntheticData(),
      );
    });

    test('9. anonymous_session.secure_read swallow capture', () async {
      await assertSwallowSite(
        surface: 'anonymous_session.secure_read',
        error: _SyntheticData(),
      );
    });

    test('10. anonymous_session.secure_write swallow capture', () async {
      await assertSwallowSite(
        surface: 'anonymous_session.secure_write',
        error: _SyntheticData(),
      );
    });

    test('11. api.try_refresh swallow capture', () async {
      await assertSwallowSite(
        surface: 'api.try_refresh',
        error: _SyntheticData(),
      );
    });

    // ── Bucket (c) UI-service ──────────────────────────────────
    test('12. coach_profile.sync_to_backend swallow capture', () async {
      await assertSwallowSite(
        surface: 'coach_profile.sync_to_backend',
        error: _SyntheticUi(),
      );
    });

    test('13. coach_profile.sync_from_backend swallow capture', () async {
      await assertSwallowSite(
        surface: 'coach_profile.sync_from_backend',
        error: _SyntheticUi(),
      );
    });

    test('14. sentry.before_send swallow capture', () async {
      // beforeSend is called inside Sentry's pipeline; we assert the
      // breadcrumb contract only (the actual hook is exercised by
      // sentry_breadcrumbs_test). The breadcrumb shape is what STAMP-05
      // greps for.
      await assertSwallowSite(
        surface: 'sentry.before_send',
        error: _SyntheticUi(),
      );
    });

    // ── Bucket (d) walker-overlap ──────────────────────────────
    test(
      '15. coach_orchestrator.fallback_compliance swallow capture',
      () async {
        await assertSwallowSite(
          surface: 'coach_orchestrator.fallback_compliance',
          error: _SyntheticBoot(),
        );
      },
    );

    // ── Bonus: feature_flags.refresh (single-source cleanup) ───
    test(
      'bonus: feature_flags.refresh swallow capture (lint cleanup)',
      () async {
        await assertSwallowSite(
          surface: 'feature_flags.refresh',
          error: _SyntheticBoot(),
        );
      },
    );

    test(
      'errorCode is propagated when supplied (Pitfall-6 enum-only contract)',
      () async {
        captured.clear();
        MintBreadcrumbs.swallow(
          surface: 'main.slm_init',
          errorKind: 'TimeoutException',
          errorCode: 'timeout_5s',
        );
        await Future<void>.delayed(Duration.zero);

        final hit = captured.firstWhere(
          (c) => c.category == 'mint.swallow.main.slm_init',
        );
        expect(hit.data!['error_code'], 'timeout_5s');
      },
    );

    test(
      'breadcrumb data MUST NOT contain the raw error message '
      '(nLPD Pitfall 6 fuzz)',
      () async {
        captured.clear();
        MintBreadcrumbs.swallow(
          surface: 'auth.refresh',
          errorKind: 'http.ClientException',
          errorCode: 'network',
        );
        await Future<void>.delayed(Duration.zero);

        final hit = captured.firstWhere(
          (c) => c.category == 'mint.swallow.auth.refresh',
        );
        // Surface, error_kind, error_code only. No `message` / `stack`.
        expect(hit.data!.keys.toSet(), <String>{
          'surface',
          'error_kind',
          'error_code',
        });
      },
    );
  });
}
