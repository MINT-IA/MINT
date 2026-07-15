import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/api_service.dart';

abstract interface class PartnerAccountabilityApi {
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  );
  Future<Map<String, dynamic>> get(String endpoint);
  Future<void> delete(String endpoint);
}

final class MintPartnerAccountabilityApi implements PartnerAccountabilityApi {
  const MintPartnerAccountabilityApi();

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) =>
      ApiService.post(endpoint, body);

  @override
  Future<Map<String, dynamic>> get(String endpoint) => ApiService.get(endpoint);

  @override
  Future<void> delete(String endpoint) => ApiService.delete(endpoint);
}

class PartnerAccountabilityException implements Exception {
  const PartnerAccountabilityException(this.status, {this.retryable = false});

  final PartnerAccountabilityReceiptStatus status;
  final bool retryable;
}

class PartnerAccountabilityService {
  PartnerAccountabilityService({PartnerAccountabilityApi? api})
      : _api = api ?? const MintPartnerAccountabilityApi();

  static const subjectKind = 'manualPartner';
  static const accountabilityKind =
      'acting_user_partner_authorization_declaration';
  static const purpose = 'one_shot_lpp_extraction';

  final PartnerAccountabilityApi _api;

  Future<PartnerAccountabilityReceipt> createReceipt({
    required String receiptId,
    required String manualPartnerOwnerId,
    required String noticeVersion,
    required String policyVersion,
  }) async {
    try {
      return PartnerAccountabilityReceipt.fromJson(
        await _api.post('/partner-accountability/receipts', <String, dynamic>{
          'receiptId': receiptId,
          'subjectOwnerToken': manualPartnerOwnerId,
          'subjectKind': subjectKind,
          'accountabilityKind': accountabilityKind,
          'purpose': purpose,
          'noticeVersion': noticeVersion,
          'policyVersion': policyVersion,
        }),
      );
    } on ApiException catch (error) {
      throw _mapApiException(error);
    }
  }

  Future<PartnerAccountabilityReceipt> status(String receiptId) async {
    try {
      return PartnerAccountabilityReceipt.fromJson(
        await _api.get(
          '/partner-accountability/receipts/$receiptId/status',
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw const PartnerAccountabilityException(
          PartnerAccountabilityReceiptStatus.erased,
        );
      }
      throw _mapApiException(error);
    }
  }

  Future<PartnerAccountabilityReceipt> revoke(String receiptId) async {
    try {
      return PartnerAccountabilityReceipt.fromJson(
        await _api.post(
          '/partner-accountability/receipts/$receiptId/revoke',
          const <String, dynamic>{},
        ),
      );
    } on ApiException catch (error) {
      throw _mapApiException(error);
    }
  }

  Future<void> erase(String receiptId) async {
    try {
      await _api.delete('/partner-accountability/receipts/$receiptId');
    } on ApiException catch (error) {
      throw _mapApiException(error);
    }
  }

  PartnerAccountabilityException _mapApiException(ApiException error) {
    if (error.isOffline) {
      return const PartnerAccountabilityException(
        PartnerAccountabilityReceiptStatus.offline,
        retryable: true,
      );
    }
    return PartnerAccountabilityException(
      PartnerAccountabilityReceiptStatus.stale,
      retryable: error.statusCode == null || error.statusCode! >= 500,
    );
  }
}
