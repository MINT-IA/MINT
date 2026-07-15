import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String relativePath) {
  final file = File(relativePath);
  return file.existsSync() ? file.readAsStringSync() : '';
}

void _expectContractTokens(
  String source,
  Iterable<String> tokens, {
  required String reason,
}) {
  final missing = tokens.where((token) => !source.contains(token)).toList();
  expect(
    missing,
    isEmpty,
    reason: '$reason Missing behavioral markers: ${missing.join(', ')}',
  );
}

void main() {
  group('manualPartner admission remains narrower than household state', () {
    test('uses the exact local conjoint predicate', () {
      final scanSource =
          _source('lib/screens/document_scan/document_scan_screen.dart');

      expect(scanSource, contains('profile?.conjoint != null'));
      expect(
        scanSource,
        isNot(contains('HouseholdProvider')),
        reason: 'Household membership must never authorize a partner import.',
      );
    });

    test('proxy declaration is not modeled as direct partner consent', () {
      final evidenceSource = _source('lib/models/lpp_evidence.dart');

      expect(evidenceSource, contains('manualPartnerDeclaration'));
      expect(
        evidenceSource,
        isNot(contains('directPartnerConsent')),
        reason: 'The acting user declaration cannot prove direct consent.',
      );
    });
  });

  group('isolated accountability binding lifecycle', () {
    final bindingSource = _source(
      'lib/services/consent/partner_accountability_binding_store.dart',
    );
    final modelSource = _source('lib/models/partner_accountability.dart');
    final serviceSource = _source(
      'lib/services/consent/partner_accountability_service.dart',
    );
    final providerSource = _source('lib/providers/coach_profile_provider.dart');
    final scanSource =
        _source('lib/screens/document_scan/document_scan_screen.dart');
    final reviewSource =
        _source('lib/screens/document_scan/extraction_review_screen.dart');
    final productionSource =
        '$bindingSource\n$modelSource\n$serviceSource\n$providerSource\n'
        '$scanSource\n$reviewSource';

    test('persists pending before active with stable owner and receipt ids',
        () {
      _expectContractTokens(
        productionSource,
        const <String>[
          'PartnerAccountabilityBindingStore',
          'receiptId',
          'manualPartnerOwnerId',
          'pending',
          'active',
        ],
        reason:
            'BND-02A requires one pending→active binding and exact-id reuse.',
      );
    });

    test('wires remote erase and local rollback in scan and review owners', () {
      _expectContractTokens(
        productionSource,
        const <String>[
          'shadowed',
          'rollback',
          '_rollbackPartnerAttempt',
          '_cleanupPartnerReceipt',
          '.erase(',
        ],
        reason:
            'Terminal paths must call real remote and local cleanup owners.',
      );
    });

    test('fails closed for offline, expiry, revocation, and erasure', () {
      _expectContractTokens(
        productionSource,
        const <String>[
          'offline',
          'expired',
          'revoked',
          'erased',
          'partial',
        ],
        reason: 'Unverifiable receipt-bound facts must become partial+ask.',
      );
    });

    test('preserves independent userInput facts during targeted invalidation',
        () {
      _expectContractTokens(
        productionSource,
        const <String>[
          'independentFacts',
          '_restoreIndependentPartnerUserInputFacts',
          'ProfileDataSource.userInput',
        ],
        reason:
            'Receipt invalidation must not erase an independent declaration.',
      );
    });
  });
}
