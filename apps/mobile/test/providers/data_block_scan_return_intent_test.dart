import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';

const _rvcOrigin = '/rente-vs-capital';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RVC LPP intent retains exact typed kind target and UUID identity', () {
    final createdAt = DateTime.utc(2026, 7, 19, 14, 30);
    final provider = ScanSessionProvider(now: () => createdAt);
    addTearDown(provider.dispose);
    final target = parseDataBlockReturnTarget(_rvcOrigin)!;

    final id = provider.retainDataBlockScanReturnIntent(
      kind: DataBlockScanReturnKind.rvcLpp,
      target: target,
    );
    final intent = provider.dataBlockScanReturnIntentById(id)!;

    expect(id, matches(_canonicalUuidV4));
    expect(intent.kind, DataBlockScanReturnKind.rvcLpp);
    expect(intent.target, same(target));
    expect(intent.target.location, _rvcOrigin);
    expect(intent.createdAt, createdAt);
    expect(intent.createdAt.isUtc, isTrue);
    expect(intent.lifecycle, DataBlockScanReturnLifecycle.created);
    expect(provider.dataBlockScanReturnIntentById('not-a-uuid'), isNull);
    expect(
      () => provider.retainDataBlockScanReturnIntent(
        kind: DataBlockScanReturnKind.rvcLpp,
        target: DataBlockReturnTarget.home,
      ),
      throwsArgumentError,
    );
  });

  test('RVC lifecycle is one-way CAS without skip back or replay', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final id = _retainRvcIntent(provider);
    final created = provider.dataBlockScanReturnIntentById(id)!;

    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.created,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.processing,
        to: DataBlockScanReturnLifecycle.created,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isTrue,
    );
    final processing = provider.dataBlockScanReturnIntentById(id)!;
    expect(processing.lifecycle, DataBlockScanReturnLifecycle.processing);
    expect(processing.kind, created.kind);
    expect(processing.target, same(created.target));
    expect(processing.createdAt, created.createdAt);
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.processing,
        to: DataBlockScanReturnLifecycle.created,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.processing,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        '11111111-1111-4111-8111-111111111111',
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isFalse,
    );
  });

  test('RVC intent registry is FIFO five and logout purge clears all', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final ids = <String>[
      for (var index = 0; index < 6; index++) _retainRvcIntent(provider),
    ];

    expect(provider.retainedDataBlockScanReturnIntentCount, 5);
    expect(provider.dataBlockScanReturnIntentById(ids.first), isNull);
    for (final retainedId in ids.skip(1)) {
      expect(provider.dataBlockScanReturnIntentById(retainedId), isNotNull);
    }

    provider.clearSessionMemoryAfterPurge();

    expect(provider.retainedDataBlockScanReturnIntentCount, 0);
    for (final id in ids) {
      expect(provider.dataBlockScanReturnIntentById(id), isNull);
    }
  });

  test('RVC discard is terminal and idempotent', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final id = _retainRvcIntent(provider);

    expect(provider.discardDataBlockScanReturnIntent(id), isTrue);
    expect(provider.dataBlockScanReturnIntentById(id), isNull);
    expect(provider.discardDataBlockScanReturnIntent(id), isFalse);
    expect(provider.retainedDataBlockScanReturnIntentCount, 0);
  });
}

String _retainRvcIntent(ScanSessionProvider provider) =>
    provider.retainDataBlockScanReturnIntent(
      kind: DataBlockScanReturnKind.rvcLpp,
      target: parseDataBlockReturnTarget(_rvcOrigin)!,
    );

final _canonicalUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
