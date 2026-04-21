// Phase 31 OBS-05 (b) — MintBreadcrumbs.complianceGuard live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
//
// D-03 LOCKED (CONTEXT.md §Implementation Decisions): the 4-level
// category MUST be `mint.<surface>.<action>.<outcome>`. Outcome is the
// 4th dotted segment (NOT carried only by SentryLevel) — this enables
// Sentry UI search `event.category:mint.compliance.guard.pass`. The
// SentryLevel enum (info / warning) remains set in parallel for
// ops filtering but is orthogonal to the category string.
//
// Exact literals:
//   passed=true  -> category = `mint.compliance.guard.pass`   level=info
//   passed=false -> category = `mint.compliance.guard.fail`   level=warning
//
// Data payload MUST NOT leak flagged term contents. Only `flagged_count`
// (int) is permitted.
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
        // Capture in memory + drop — no network.
        options.beforeBreadcrumb = (crumb, hint) {
          if (crumb != null) captured.add(crumb);
          return null;
        };
        // Belt+suspenders: drop any event before transport.
        options.beforeSend = (event, hint) => null;
      },
    );
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('MintBreadcrumbs.complianceGuard (D-03 4-level)', () {
    test(
      'emits category mint.compliance.guard.pass on passed=true',
      () async {
        MintBreadcrumbs.complianceGuard(
          passed: true,
          surface: 'coach_reply',
        );
        await Future<void>.delayed(Duration.zero);

        expect(captured, hasLength(1));
        final c = captured.single;
        expect(c.category, 'mint.compliance.guard.pass');
        expect(c.level, SentryLevel.info);
        expect(c.data, isNotNull);
        expect(c.data!['passed'], isTrue);
        expect(c.data!['surface'], 'coach_reply');
        expect(c.data!.containsKey('flagged_count'), isFalse);
      },
    );

    test(
      'emits category mint.compliance.guard.fail on passed=false '
      'with flagged_count int only (no term strings leaked)',
      () async {
        MintBreadcrumbs.complianceGuard(
          passed: false,
          surface: 'premier_eclairage',
          flaggedTerms: ['garanti', 'optimal'],
        );
        await Future<void>.delayed(Duration.zero);

        expect(captured, hasLength(1));
        final c = captured.single;
        expect(c.category, 'mint.compliance.guard.fail');
        expect(c.level, SentryLevel.warning);
        expect(c.data, isNotNull);
        expect(c.data!['passed'], isFalse);
        expect(c.data!['surface'], 'premier_eclairage');
        expect(c.data!['flagged_count'], 2);
        // PII discipline — term strings must NEVER reach Sentry.
        final serialised = c.data!.values.map((v) => '$v').join(' | ');
        expect(serialised, isNot(contains('garanti')));
        expect(serialised, isNot(contains('optimal')));
      },
    );
  });
}
