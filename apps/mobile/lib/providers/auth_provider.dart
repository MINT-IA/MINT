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

      // Extract token and user data from response
      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      await AuthService.saveToken(
        token,
        user['id'] as String,
        user['email'] as String,
        displayName: user['display_name'] as String?,
      );

      _userId = user['id'] as String;
      _email = user['email'] as String;
      _displayName = user['display_name'] as String?;
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

      // Extract token and user data from response
      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      await AuthService.saveToken(
        token,
        user['id'] as String,
        user['email'] as String,
        displayName: user['display_name'] as String?,
      );

      _userId = user['id'] as String;
      _email = user['email'] as String;
      _displayName = user['display_name'] as String?;
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
