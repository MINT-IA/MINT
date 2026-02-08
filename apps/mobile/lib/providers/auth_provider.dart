import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/api_service.dart';

/// Provider for managing authentication state
/// Handles login, register, logout, and auth persistence
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userId;
  String? _email;
  String? _displayName;
  bool _isLoading = false;
  String? _error;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check stored auth on app startup
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        _userId = await AuthService.getUserId();
        _email = await AuthService.getUserEmail();
        _displayName = await AuthService.getDisplayName();
        _isLoggedIn = true;
        _error = null;
      }
    } catch (e) {
      _error = e.toString();
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register new user
  Future<bool> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        email,
        password,
        displayName: displayName,
      );

      // Backend returns flat: { access_token, token_type, user_id, email }
      final token = response['access_token'] as String;
      final userId = response['user_id']?.toString() ?? '';
      final userEmail = response['email'] as String;

      await AuthService.saveToken(
        token,
        userId,
        userEmail,
        displayName: response['display_name'] as String?,
      );

      _userId = userId;
      _email = userEmail;
      _displayName = response['display_name'] as String?;
      _isLoggedIn = true;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);

      // Backend returns flat: { access_token, token_type, user_id, email }
      final token = response['access_token'] as String;
      final userId = response['user_id']?.toString() ?? '';
      final userEmail = response['email'] as String;

      await AuthService.saveToken(
        token,
        userId,
        userEmail,
        displayName: response['display_name'] as String?,
      );

      _userId = userId;
      _email = userEmail;
      _displayName = response['display_name'] as String?;
      _isLoggedIn = true;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await AuthService.logout();
    _isLoggedIn = false;
    _userId = null;
    _email = null;
    _displayName = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
