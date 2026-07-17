import 'dart:convert';

import 'package:flutter/foundation.dart';

enum PartnerAccountabilityReceiptStatus {
  active,
  stale,
  expired,
  revoked,
  erased,
  offline,
}

enum PartnerAccountabilityBindingState { pending, active, partial }

/// Volatile proof that one manual-partner document may proceed through review.
///
/// This context deliberately has no JSON representation: receipt linkage is
/// carried only by the bounded scan session and is rechecked against secure
/// pending state immediately before ledger acceptance.
@immutable
class ManualPartnerAccountabilityContext {
  const ManualPartnerAccountabilityContext({
    required this.receiptId,
    required this.ownerId,
    required this.expiresAt,
    required this.noticeVersion,
    required this.policyVersion,
    required this.receiptStatus,
  });

  final String receiptId;
  final String ownerId;
  final DateTime expiresAt;
  final String noticeVersion;
  final String policyVersion;
  final PartnerAccountabilityReceiptStatus receiptStatus;

  bool isActiveAt(DateTime now) =>
      receiptStatus == PartnerAccountabilityReceiptStatus.active &&
      receiptId.isNotEmpty &&
      ownerId.isNotEmpty &&
      noticeVersion.isNotEmpty &&
      policyVersion.isNotEmpty &&
      now.toUtc().isBefore(expiresAt.toUtc());

  bool matchesAuthorization({
    required String? receiptId,
    required String? ownerId,
  }) =>
      this.receiptId == receiptId && this.ownerId == ownerId;

  bool matchesPending(PartnerAccountabilityBinding pending) =>
      pending.state == PartnerAccountabilityBindingState.pending &&
      pending.receiptId == receiptId &&
      pending.manualPartnerOwnerId == ownerId &&
      pending.noticeVersion == noticeVersion &&
      pending.policyVersion == policyVersion &&
      pending.hasCreatedReceipt &&
      pending.expiresAt?.toUtc() == expiresAt.toUtc();
}

/// Runtime proof supplied only after the named external legal/privacy facts
/// have been independently verified. Production has no fabricated defaults.
@immutable
class PartnerAccountabilityExternalGate {
  const PartnerAccountabilityExternalGate({
    required this.noticeVersion,
    required this.policyVersion,
    required this.effectiveAt,
    required this.expiresAt,
    required this.controllerIdentity,
    required this.privacyContact,
    required this.recipient,
    required this.processingRegions,
    required this.transferMechanism,
    required this.retentionContract,
    required this.rightsChannel,
    required this.aipdDecision,
  });

  final String noticeVersion;
  final String policyVersion;
  final DateTime effectiveAt;
  final DateTime expiresAt;
  final String controllerIdentity;
  final String privacyContact;
  final String recipient;
  final String processingRegions;
  final String transferMechanism;
  final String retentionContract;
  final String rightsChannel;
  final String aipdDecision;

  bool isCurrentAt(DateTime now) {
    final current = now.toUtc();
    return noticeVersion.isNotEmpty &&
        policyVersion.isNotEmpty &&
        controllerIdentity.isNotEmpty &&
        privacyContact.isNotEmpty &&
        recipient.isNotEmpty &&
        processingRegions.isNotEmpty &&
        transferMechanism.isNotEmpty &&
        retentionContract.isNotEmpty &&
        rightsChannel.isNotEmpty &&
        aipdDecision.isNotEmpty &&
        !effectiveAt.toUtc().isAfter(current) &&
        current.isBefore(expiresAt.toUtc());
  }
}

@immutable
class PartnerAccountabilityReceipt {
  const PartnerAccountabilityReceipt({
    required this.receiptId,
    required this.status,
    required this.noticeVersion,
    required this.policyVersion,
    this.declaredAt,
    this.expiresAt,
  });

  final String receiptId;
  final PartnerAccountabilityReceiptStatus status;
  final String noticeVersion;
  final String policyVersion;
  final DateTime? declaredAt;
  final DateTime? expiresAt;

  bool get isCurrent => status == PartnerAccountabilityReceiptStatus.active;

  factory PartnerAccountabilityReceipt.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;
    return PartnerAccountabilityReceipt(
      receiptId: json['receiptId'] as String,
      status: PartnerAccountabilityReceiptStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => PartnerAccountabilityReceiptStatus.stale,
      ),
      noticeVersion: json['noticeVersion'] as String? ?? '',
      policyVersion: json['policyVersion'] as String? ?? '',
      declaredAt:
          DateTime.tryParse(json['declaredAt'] as String? ?? '')?.toUtc(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '')?.toUtc(),
    );
  }
}

@immutable
class PartnerAccountabilityBinding {
  const PartnerAccountabilityBinding({
    required this.receiptId,
    required this.manualPartnerOwnerId,
    required this.state,
    required this.createdAt,
    required this.noticeVersion,
    required this.policyVersion,
    required this.privacyContact,
    required this.rightsChannel,
    this.lppSnapshotId,
    this.lastVerifiedAt,
    this.receiptCreatedAt,
    this.expiresAt,
    this.failureStatus,
  });

  final String receiptId;
  final String manualPartnerOwnerId;
  final PartnerAccountabilityBindingState state;
  final DateTime createdAt;
  final String noticeVersion;
  final String policyVersion;
  final String privacyContact;
  final String rightsChannel;
  final String? lppSnapshotId;
  final DateTime? lastVerifiedAt;
  final DateTime? receiptCreatedAt;
  final DateTime? expiresAt;
  final PartnerAccountabilityReceiptStatus? failureStatus;

  bool get hasCreatedReceipt => receiptCreatedAt != null;

  bool isCurrentAt(DateTime now, {Duration maxAge = const Duration(hours: 6)}) {
    final verified = lastVerifiedAt;
    final expiry = expiresAt;
    return state == PartnerAccountabilityBindingState.active &&
        failureStatus == null &&
        lppSnapshotId != null &&
        lppSnapshotId!.isNotEmpty &&
        privacyContact.isNotEmpty &&
        rightsChannel.isNotEmpty &&
        verified != null &&
        expiry != null &&
        !verified.isAfter(now.toUtc()) &&
        now.toUtc().isBefore(expiry) &&
        now.toUtc().difference(verified) <= maxAge;
  }

  PartnerAccountabilityBinding copyWith({
    PartnerAccountabilityBindingState? state,
    String? lppSnapshotId,
    DateTime? lastVerifiedAt,
    DateTime? receiptCreatedAt,
    DateTime? expiresAt,
    PartnerAccountabilityReceiptStatus? failureStatus,
    bool clearFailureStatus = false,
  }) {
    return PartnerAccountabilityBinding(
      receiptId: receiptId,
      manualPartnerOwnerId: manualPartnerOwnerId,
      state: state ?? this.state,
      createdAt: createdAt,
      noticeVersion: noticeVersion,
      policyVersion: policyVersion,
      privacyContact: privacyContact,
      rightsChannel: rightsChannel,
      lppSnapshotId: lppSnapshotId ?? this.lppSnapshotId,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      receiptCreatedAt: receiptCreatedAt ?? this.receiptCreatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      failureStatus:
          clearFailureStatus ? null : failureStatus ?? this.failureStatus,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'receiptId': receiptId,
        'manualPartnerOwnerId': manualPartnerOwnerId,
        'state': state.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'noticeVersion': noticeVersion,
        'policyVersion': policyVersion,
        'privacyContact': privacyContact,
        'rightsChannel': rightsChannel,
        'lppSnapshotId': lppSnapshotId,
        'lastVerifiedAt': lastVerifiedAt?.toUtc().toIso8601String(),
        'receiptCreatedAt': receiptCreatedAt?.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'failureStatus': failureStatus?.name,
      };

  static PartnerAccountabilityBinding? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(raw);
      final state = PartnerAccountabilityBindingState.values.firstWhere(
        (value) => value.name == json['state'],
      );
      final failureName = json['failureStatus'] as String?;
      final privacyContact = json['privacyContact'] as String;
      final rightsChannel = json['rightsChannel'] as String;
      if (privacyContact.isEmpty || rightsChannel.isEmpty) return null;
      return PartnerAccountabilityBinding(
        receiptId: json['receiptId'] as String,
        manualPartnerOwnerId: json['manualPartnerOwnerId'] as String,
        state: state,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        noticeVersion: json['noticeVersion'] as String,
        policyVersion: json['policyVersion'] as String,
        privacyContact: privacyContact,
        rightsChannel: rightsChannel,
        lppSnapshotId: json['lppSnapshotId'] as String?,
        lastVerifiedAt:
            DateTime.tryParse(json['lastVerifiedAt'] as String? ?? '')?.toUtc(),
        receiptCreatedAt:
            DateTime.tryParse(json['receiptCreatedAt'] as String? ?? '')
                ?.toUtc(),
        expiresAt:
            DateTime.tryParse(json['expiresAt'] as String? ?? '')?.toUtc(),
        failureStatus: failureName == null
            ? null
            : PartnerAccountabilityReceiptStatus.values.firstWhere(
                (value) => value.name == failureName,
              ),
      );
    } catch (_) {
      return null;
    }
  }
}

@immutable
class PartnerAccountabilityBindingEnvelope {
  const PartnerAccountabilityBindingEnvelope({
    this.active,
    this.pending,
    this.shadowed,
  });

  final PartnerAccountabilityBinding? active;
  final PartnerAccountabilityBinding? pending;
  final PartnerAccountabilityBinding? shadowed;

  PartnerAccountabilityBinding? get effective => pending ?? active;

  String toJsonString() => jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'active': active?.toJson(),
        'pending': pending?.toJson(),
        'shadowed': shadowed?.toJson(),
      });

  static PartnerAccountabilityBindingEnvelope fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const PartnerAccountabilityBindingEnvelope();
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['schemaVersion'] != 1) {
        return const PartnerAccountabilityBindingEnvelope();
      }
      return PartnerAccountabilityBindingEnvelope(
        active: PartnerAccountabilityBinding.fromJson(json['active']),
        pending: PartnerAccountabilityBinding.fromJson(json['pending']),
        shadowed: PartnerAccountabilityBinding.fromJson(json['shadowed']),
      );
    } catch (_) {
      return const PartnerAccountabilityBindingEnvelope();
    }
  }
}
