// Phase 31 OBS-05 (d) — MintBreadcrumbs.featureFlagsRefresh live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
//
// D-03 LOCKED EXACT LITERALS (CONTEXT.md):
//   success=true  -> category = `mint.feature_flags.refresh.success`  level=info
//   success=false -> category = `mint.feature_flags.refresh.failure`  level=warning
//
// NOTE: failure literal is `failure` — NOT `error` — on this surface per
// CONTEXT.md asymmetry (feature-flag refresh can fail on network/parse
// without an uncaught exception, distinct from save_fact's `error`).
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <Breadcrumb>[];

  setUp(() async {
    captured.clear();
    await Sentry.init(
      (options) {
        options.dsn = _fakeDsn;
        options.beforeBreadcrumb = (crumb, hint) {
          if (crumb != null) captured.add(crumb);
          return null;
        };
        options.beforeSend = (event, hint) => null;
      },
    );
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('MintBreadcrumbs.featureFlagsRefresh (D-03 4-level)', () {
    test(
      'emits category mint.feature_flags.refresh.success on success=true '
      'with flag_count int',
      () async {
        MintBreadcrumbs.featureFlagsRefresh(success: true, flagCount: 11);
        await Future<void>.delayed(Duration.zero);

        expect(captured, hasLength(1));
        final c = captured.single;
        expect(c.category, 'mint.feature_flags.refresh.success');
        expect(c.level, SentryLevel.info);
        expect(c.data!['success'], isTrue);
        expect(c.data!['flag_count'], 11);
        expect(c.data!.containsKey('error_code'), isFalse);
      },
    );

    test(
      'emits category mint.feature_flags.refresh.failure on success=false '
      'with error_code enum only (literal `failure`, not `error`)',
      () async {
        MintBreadcrumbs.featureFlagsRefresh(
          success: false,
          errorCode: 'network_timeout',
        );
        await Future<void>.delayed(Duration.zero);

        expect(captured, hasLength(1));
        final c = captured.single;
        expect(c.category, 'mint.feature_flags.refresh.failure');
        expect(c.level, SentryLevel.warning);
        expect(c.data!['success'], isFalse);
        expect(c.data!['error_code'], 'network_timeout');
        expect(c.data!.containsKey('flag_count'), isFalse);
      },
    );
  });
}
