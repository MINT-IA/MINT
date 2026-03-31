import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/household_service.dart';

/// Provider for Couple+ household management.
///
/// Wraps [HouseholdService] with reactive state management.
/// Fetches household details, manages invitations, and tracks membership.
class HouseholdProvider extends ChangeNotifier {
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
  bool get hasPendingInvite =>
      _members.any((m) => m['status'] == 'pending');

  /// Fetch household from backend.
  Future<void> loadHousehold() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await HouseholdService.getHousehold(
        token,
        ApiService.baseUrl,
      );
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
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Invite a partner by email. Returns the invitation code on success.
  Future<String?> invitePartner(String email) async {
    final token = await AuthService.getToken();
    if (token == null) {
      _error = 'ERROR_NOT_AUTHENTICATED'; // DECISION: use error code — no BuildContext in provider, UI layer maps to i18n
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await HouseholdService.invitePartner(
        token,
        ApiService.baseUrl,
        email,
      );
      _pendingInviteCode = data['invitation_code'] as String?;
      await loadHousehold();
      return _pendingInviteCode;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Accept an invitation code.
  Future<bool> acceptInvitation(String code) async {
    final token = await AuthService.getToken();
    if (token == null) {
      _error = 'ERROR_NOT_AUTHENTICATED'; // DECISION: use error code — no BuildContext in provider, UI layer maps to i18n
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await HouseholdService.acceptInvitation(
        token,
        ApiService.baseUrl,
        code,
      );
      await loadHousehold();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Revoke a member from the household.
  Future<bool> revokeMember(String userId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await HouseholdService.revokeMember(
        token,
        ApiService.baseUrl,
        userId,
      );
      await loadHousehold();
      return true;
    } catch (e) {
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
}
