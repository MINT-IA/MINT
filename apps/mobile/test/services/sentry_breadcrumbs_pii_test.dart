// Phase 31 OBS-05 (c) — MintBreadcrumbs.saveFact PII fuzz live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
//
// D-03 LOCKED EXACT LITERALS (CONTEXT.md): the category uses the 4-level
// hierarchy — revision dropped the intermediate `tool` segment.
//   success=true  -> category = `mint.coach.save_fact.success`  level=info
//   success=false -> category = `mint.coach.save_fact.error`    level=error
//
// The `factKind` is an enum value — NEVER the factValue itself. Leaking
// factValue through a breadcrumb would regress Pitfall 6 (A1 secondary):
// CHF amounts, AVS numbers, IBANs must NOT reach Sentry.
//
// Fuzz: 100 breadcrumbs emitted across all factKind values, emitted
// payload grepped for patterns CHF[- ]?\d+, 756.\d{4}, [A-Z]{2}\d{2}[A-Z0-9]+.
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

// Canonical factKind enum values mirrored from backend
// services/backend/app/services/privacy/fact_key_allowlist.py. Safe to
// ship through Sentry — none contain PII themselves.
const _factKinds = <String>[
  'income_monthly_net',
  'housing_cost_period_chf',
  'third_pillar_balance',
  'employer_country',
  'lpp_insured_salary',
  'avs_lacunes_status',
  'has_consumer_debt',
  'canton',
  'residence_permit',
  'net_income_period_chf',
];

final _chfPattern = RegExp(r'CHF[- ]?\d+', caseSensitive: false);
final _avsPattern = RegExp(r'756\.\d{4}');
final _ibanPattern = RegExp(r'CH\d{2}[A-Z0-9]{4,}');

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

  group('MintBreadcrumbs.saveFact (D-03 4-level + PII discipline)', () {
    test('emits category mint.coach.save_fact.success on success=true', () async {
      MintBreadcrumbs.saveFact(success: true, factKind: 'income_monthly_net');
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      final c = captured.single;
      expect(c.category, 'mint.coach.save_fact.success');
      expect(c.level, SentryLevel.info);
      expect(c.data!['success'], isTrue);
      expect(c.data!['fact_kind'], 'income_monthly_net');
      expect(c.data!.containsKey('error_code'), isFalse);
    });

    test('emits category mint.coach.save_fact.error on success=false', () async {
      MintBreadcrumbs.saveFact(
        success: false,
        factKind: 'third_pillar_balance',
        errorCode: 'timeout',
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      final c = captured.single;
      expect(c.category, 'mint.coach.save_fact.error');
      expect(c.level, SentryLevel.error);
      expect(c.data!['success'], isFalse);
      expect(c.data!['fact_kind'], 'third_pillar_balance');
      expect(c.data!['error_code'], 'timeout');
    });

    test(
      'fuzz 100 breadcrumbs across all factKind enum values emits '
      'ZERO PII patterns (CHF / AVS 756. / IBAN)',
      () async {
        for (var i = 0; i < 100; i++) {
          final kind = _factKinds[i % _factKinds.length];
          final success = i.isEven;
          MintBreadcrumbs.saveFact(
            success: success,
            factKind: kind,
            errorCode: success ? null : 'code_$i',
          );
        }
        await Future<void>.delayed(Duration.zero);

        expect(captured, hasLength(100));
        for (final c in captured) {
          final serialised = <String>[
            c.category ?? '',
            for (final v in (c.data ?? {}).values) '$v',
          ].join(' | ');
          expect(
            _chfPattern.hasMatch(serialised),
            isFalse,
            reason: 'CHF pattern leaked in: $serialised',
          );
          expect(
            _avsPattern.hasMatch(serialised),
            isFalse,
            reason: 'AVS 756. pattern leaked in: $serialised',
          );
          expect(
            _ibanPattern.hasMatch(serialised),
            isFalse,
            reason: 'IBAN pattern leaked in: $serialised',
          );
          // D-03 revision: no intermediate `tool` segment.
          expect(c.category, isNot(contains('.tool.')));
        }
      },
    );
  });
}
