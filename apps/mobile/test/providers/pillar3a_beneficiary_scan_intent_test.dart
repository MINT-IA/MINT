import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';

const _contractA = '11111111-1111-4111-8111-111111111111';
const _referenceA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opaque insertion and replacement intents require exact return URI', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);

    final insertionId = provider.retainPillar3aBeneficiaryScanIntent(
      kind: Pillar3aBeneficiaryScanIntentKind.insertion,
      returnUri: '/retraite',
    );
    final replacementId = provider.retainPillar3aBeneficiaryScanIntent(
      kind: Pillar3aBeneficiaryScanIntentKind.replacement,
      contractReferenceId: _contractA,
      expectedPreviousReferenceId: _referenceA,
      returnUri: '/retraite',
    );

    expect(insertionId, isNot(replacementId));
    expect(insertionId, isNot(contains(_contractA)));
    expect(insertionId, isNot(contains(_referenceA)));
    expect(
      provider
          .pillar3aBeneficiaryScanIntentById(
            insertionId,
            returnUri: '/retraite',
          )
          ?.kind,
      Pillar3aBeneficiaryScanIntentKind.insertion,
    );
    expect(
      provider
          .pillar3aBeneficiaryScanIntentById(
            replacementId,
            returnUri: '/retraite',
          )
          ?.expectedPreviousReferenceId,
      _referenceA,
    );
    final replacement = provider.pillar3aBeneficiaryScanIntentById(
      replacementId,
      returnUri: '/retraite',
    )!;
    final insertion = provider.pillar3aBeneficiaryScanIntentById(
      insertionId,
      returnUri: '/retraite',
    )!;
    expect(
      insertion.contractReferenceId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(insertion.expectedPreviousReferenceId, isNull);
    expect(insertion.contractReferenceId, isNot(insertionId));
    expect(replacement.contractReferenceId, _contractA);
    expect(replacement.createdAt.isUtc, isTrue);
    expect(
      replacement.lifecycle,
      Pillar3aBeneficiaryScanIntentLifecycle.created,
    );
    for (final invalidReturn in <String>[
      '/retraite/',
      '/retraite?from=scan',
      'https://example.test/retraite',
      '/coach',
      '',
    ]) {
      expect(
        provider.pillar3aBeneficiaryScanIntentById(
          insertionId,
          returnUri: invalidReturn,
        ),
        isNull,
      );
    }
  });

  test('intent lifecycle is monotonic, CAS guarded, and terminal', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final id = provider.retainPillar3aBeneficiaryScanIntent(
      kind: Pillar3aBeneficiaryScanIntentKind.replacement,
      contractReferenceId: _contractA,
      expectedPreviousReferenceId: _referenceA,
      returnUri: '/retraite',
    );
    final createdAt = provider
        .pillar3aBeneficiaryScanIntentById(id, returnUri: '/retraite')!
        .createdAt;

    expect(
      provider.advancePillar3aBeneficiaryScanIntent(
        id,
        from: Pillar3aBeneficiaryScanIntentLifecycle.created,
        to: Pillar3aBeneficiaryScanIntentLifecycle.reviewRetained,
      ),
      isFalse,
    );
    for (final transition in <(
      Pillar3aBeneficiaryScanIntentLifecycle,
      Pillar3aBeneficiaryScanIntentLifecycle
    )>[
      (
        Pillar3aBeneficiaryScanIntentLifecycle.created,
        Pillar3aBeneficiaryScanIntentLifecycle.processing,
      ),
      (
        Pillar3aBeneficiaryScanIntentLifecycle.processing,
        Pillar3aBeneficiaryScanIntentLifecycle.reviewRetained,
      ),
      (
        Pillar3aBeneficiaryScanIntentLifecycle.reviewRetained,
        Pillar3aBeneficiaryScanIntentLifecycle.ledgerAcceptedAwaitingBnd,
      ),
    ]) {
      expect(
        provider.advancePillar3aBeneficiaryScanIntent(
          id,
          from: transition.$1,
          to: transition.$2,
        ),
        isTrue,
      );
    }
    final awaitingBnd = provider.pillar3aBeneficiaryScanIntentById(
      id,
      returnUri: '/retraite',
    )!;
    expect(awaitingBnd.createdAt, createdAt);
    expect(awaitingBnd.kind, Pillar3aBeneficiaryScanIntentKind.replacement);
    expect(awaitingBnd.contractReferenceId, _contractA);
    expect(awaitingBnd.expectedPreviousReferenceId, _referenceA);
    expect(
      provider.advancePillar3aBeneficiaryScanIntent(
        id,
        from: Pillar3aBeneficiaryScanIntentLifecycle.ledgerAcceptedAwaitingBnd,
        to: Pillar3aBeneficiaryScanIntentLifecycle.reviewRetained,
      ),
      isFalse,
    );
    expect(
      provider.completePillar3aBeneficiaryScanIntent(id),
      isTrue,
    );
    expect(
      provider.pillar3aBeneficiaryScanIntentById(
        id,
        returnUri: '/retraite',
      ),
      isNull,
    );
    expect(provider.completePillar3aBeneficiaryScanIntent(id), isFalse);
    expect(
      provider.advancePillar3aBeneficiaryScanIntent(
        id,
        from: Pillar3aBeneficiaryScanIntentLifecycle.ledgerAcceptedAwaitingBnd,
        to: Pillar3aBeneficiaryScanIntentLifecycle.ledgerAcceptedAwaitingBnd,
      ),
      isFalse,
    );
  });

  test('intent registry is FIFO five, discardable, and purged on logout', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final ids = <String>[
      for (var index = 0; index < 6; index++)
        provider.retainPillar3aBeneficiaryScanIntent(
          kind: Pillar3aBeneficiaryScanIntentKind.insertion,
          returnUri: '/retraite',
        ),
    ];

    expect(provider.retainedPillar3aBeneficiaryScanIntentCount, 5);
    expect(
      provider.pillar3aBeneficiaryScanIntentById(
        ids.first,
        returnUri: '/retraite',
      ),
      isNull,
    );
    expect(
      provider.pillar3aBeneficiaryScanIntentById(
        ids.last,
        returnUri: '/retraite',
      ),
      isNotNull,
    );

    provider.discardPillar3aBeneficiaryScanIntent(ids.last);
    expect(provider.retainedPillar3aBeneficiaryScanIntentCount, 4);
    provider.clearSessionMemoryAfterPurge();
    expect(provider.retainedPillar3aBeneficiaryScanIntentCount, 0);
  });

  test('invalid intent shapes fail before entering the registry', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);

    expect(
      () => provider.retainPillar3aBeneficiaryScanIntent(
        kind: Pillar3aBeneficiaryScanIntentKind.replacement,
        returnUri: '/retraite',
      ),
      throwsArgumentError,
    );
    expect(
      () => provider.retainPillar3aBeneficiaryScanIntent(
        kind: Pillar3aBeneficiaryScanIntentKind.insertion,
        contractReferenceId: _contractA,
        expectedPreviousReferenceId: _referenceA,
        returnUri: '/retraite',
      ),
      throwsArgumentError,
    );
    expect(
      () => provider.retainPillar3aBeneficiaryScanIntent(
        kind: Pillar3aBeneficiaryScanIntentKind.insertion,
        returnUri: '/coach',
      ),
      throwsArgumentError,
    );
  });
}
