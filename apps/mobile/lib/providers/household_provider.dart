import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/household_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';

/// Provider for Couple+ household management.
///
/// Wraps [HouseholdService] with reactive state management.
/// Fetches household details, manages invitations, and tracks membership.
class HouseholdProvider extends ChangeNotifier {
  HouseholdProvider({
    SessionEpoch? sessionEpoch,
    Future<Map<String, dynamic>?> Function()? loadAction,
    Future<Map<String, dynamic>> Function(String)? inviteAction,
    Future<void> Function(String)? acceptAction,
    Future<void> Function(String)? revokeAction,
  })  : _sessionEpoch = sessionEpoch ?? SessionEpoch(),
        _loadAction = loadAction ?? HouseholdService().getHousehold,
        _inviteAction = inviteAction ?? HouseholdService().invitePartner,
        _acceptAction = acceptAction ??
            ((code) async {
              await HouseholdService().acceptInvitation(code);
            }),
        _revokeAction = revokeAction ??
            ((userId) async {
              await HouseholdService().revokeMember(userId);
            });

  final SessionEpoch _sessionEpoch;
  final Future<Map<String, dynamic>?> Function() _loadAction;
  final Future<Map<String, dynamic>> Function(String) _inviteAction;
  final Future<void> Function(String) _acceptAction;
  final Future<void> Function(String) _revokeAction;
  Map<String, dynamic>? _household;
  List<Map<String, dynamic>> _members = [];
  String? _role;
  bool _isLoading = false;
  String? _error;
  String? _pendingInviteCode;

  Map<String, dynamic>? get household => _household;
  List<Map<String, dynamic>> get members => _members;
  String? get role => _role;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pendingInviteCode => _pendingInviteCode;

  bool get hasHousehold => _household != null;
  bool get isOwner => _role == 'owner';

  /// Active (non-revoked) members count.
  int get activeMemberCount =>
      _members.where((m) => m['status'] == 'active').length;

  /// Partner info (the other active member, if any).
  Map<String, dynamic>? get partner {
    try {
      return _members.firstWhere(
        (m) => m['status'] == 'active' && m['role'] == 'partner',
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether there is a pending invitation.
  bool get hasPendingInvite => _members.any((m) => m['status'] == 'pending');

  /// Network timeout for household API calls.
  static const _kTimeout = Duration(seconds: 15);

  /// Fetch household from backend.
  Future<void> loadHousehold() async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _loadAction().timeout(_kTimeout);
      guard.assertCurrent();
      if (data != null) {
        _household = data['household'] as Map<String, dynamic>?;
        final rawMembers = data['members'] as List?;
        _members = rawMembers?.cast<Map<String, dynamic>>() ?? [];
        _role = data['role'] as String?;
      } else {
        _household = null;
        _members = [];
        _role = null;
      }
    } on SessionEpochInvalidated {
      return;
    } on ApiException catch (error) {
      guard.assertCurrent();
      if (error.errorCode != ApiErrorCode.authenticationRequired) {
        _error = error.toString();
      }
    } on TimeoutException {
      guard.assertCurrent();
      _error = 'ERROR_TIMEOUT';
    } catch (e) {
      guard.assertCurrent();
      _error = e.toString();
    } finally {
      try {
        guard.assertCurrent();
        _isLoading = false;
        notifyListeners();
      } on SessionEpochInvalidated {
        // Session termination owns the cleared state.
      }
    }
  }

  /// Invite a partner by email. Returns the invitation code on success.
  Future<String?> invitePartner(String email) async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _inviteAction(email).timeout(_kTimeout);
      guard.assertCurrent();
      _pendingInviteCode = data['invitation_code'] as String?;
      await loadHousehold();
      guard.assertCurrent();
      return _pendingInviteCode;
    } on SessionEpochInvalidated {
      return null;
    } on ApiException catch (error) {
      guard.assertCurrent();
      _error = error.errorCode == ApiErrorCode.authenticationRequired
          ? 'ERROR_NOT_AUTHENTICATED'
          : error.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    } on TimeoutException {
      guard.assertCurrent();
      _error = 'ERROR_TIMEOUT';
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      guard.assertCurrent();
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Accept an invitation code.
  Future<bool> acceptInvitation(String code) async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _acceptAction(code).timeout(_kTimeout);
      guard.assertCurrent();
      await loadHousehold();
      guard.assertCurrent();
      return true;
    } on SessionEpochInvalidated {
      return false;
    } on ApiException catch (error) {
      guard.assertCurrent();
      _error = error.errorCode == ApiErrorCode.authenticationRequired
          ? 'ERROR_NOT_AUTHENTICATED'
          : error.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } on TimeoutException {
      guard.assertCurrent();
      _error = 'ERROR_TIMEOUT';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      guard.assertCurrent();
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Revoke a member from the household.
  Future<bool> revokeMember(String userId) async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _revokeAction(userId).timeout(_kTimeout);
      guard.assertCurrent();
      await loadHousehold();
      guard.assertCurrent();
      return true;
    } on SessionEpochInvalidated {
      return false;
    } on ApiException catch (error) {
      guard.assertCurrent();
      _error = error.errorCode == ApiErrorCode.authenticationRequired
          ? 'ERROR_NOT_AUTHENTICATED'
          : error.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } on TimeoutException {
      guard.assertCurrent();
      _error = 'ERROR_TIMEOUT';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      guard.assertCurrent();
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error state.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clears account-scoped state after the durable session purge succeeds.
  void clearSessionMemoryAfterPurge() {
    _household = null;
    _members = [];
    _role = null;
    _isLoading = false;
    _error = null;
    _pendingInviteCode = null;
    notifyListeners();
  }
}
