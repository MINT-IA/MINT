import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';

final class _FakeApi implements PartnerAccountabilityApi {
  final calls = <(String, Map<String, dynamic>)>[];
  Object? nextError;

  Map<String, dynamic> response = <String, dynamic>{
    'receiptId': '11111111-1111-4111-8111-111111111111',
    'status': 'active',
    'noticeVersion': 'notice-v1',
    'policyVersion': 'policy-v1',
    'declaredAt': '2026-07-15T12:00:00Z',
    'expiresAt': '2027-07-15T12:00:00Z',
  };

  Never _throw() => throw nextError!;

  @override
  Future<void> delete(String endpoint) async {
    calls.add((endpoint, const <String, dynamic>{}));
    if (nextError != null) _throw();
  }

  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    calls.add((endpoint, const <String, dynamic>{}));
    if (nextError != null) _throw();
    return response;
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    calls.add((endpoint, Map<String, dynamic>.from(body)));
    if (nextError != null) _throw();
    return response;
  }
}

void main() {
  const receiptId = '11111111-1111-4111-8111-111111111111';
  const ownerId = '22222222-2222-4222-8222-222222222222';

  test('create retry sends the exact same minimized body and IDs', () async {
    final api = _FakeApi();
    final service = PartnerAccountabilityService(api: api);
    for (var i = 0; i < 2; i++) {
      final receipt = await service.createReceipt(
        receiptId: receiptId,
        manualPartnerOwnerId: ownerId,
        noticeVersion: 'notice-v1',
        policyVersion: 'policy-v1',
      );
      expect(receipt.expiresAt, DateTime.utc(2027, 7, 15, 12));
    }

    expect(api.calls, hasLength(2));
    expect(api.calls[0].$2, api.calls[1].$2);
    expect(api.calls[0].$2, <String, dynamic>{
      'receiptId': receiptId,
      'subjectOwnerToken': ownerId,
      'subjectKind': 'manualPartner',
      'accountabilityKind': 'acting_user_partner_authorization_declaration',
      'purpose': 'one_shot_lpp_extraction',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
    });
    for (final forbidden in const <String>[
      'partnerName',
      'partnerEmail',
      'documentSha',
      'acquisitionId',
      'imageBase64',
      'value',
      'ipAddress',
    ]) {
      expect(api.calls[0].$2.keys, isNot(contains(forbidden)));
    }
  });

  test('status maps 404 to erased and offline to retryable partial', () async {
    final erasedApi = _FakeApi()
      ..nextError = const ApiException('missing', statusCode: 404);
    final erased =
        PartnerAccountabilityService(api: erasedApi).status(receiptId);
    await expectLater(
      erased,
      throwsA(
        isA<PartnerAccountabilityException>().having(
          (error) => error.status,
          'status',
          PartnerAccountabilityReceiptStatus.erased,
        ),
      ),
    );

    final offlineApi = _FakeApi()..nextError = ApiException.offline();
    final offline =
        PartnerAccountabilityService(api: offlineApi).status(receiptId);
    await expectLater(
      offline,
      throwsA(
        isA<PartnerAccountabilityException>()
            .having(
              (error) => error.status,
              'status',
              PartnerAccountabilityReceiptStatus.offline,
            )
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });
}
