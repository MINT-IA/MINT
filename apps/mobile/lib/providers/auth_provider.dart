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

      // Backend returns flat: { access_token, refresh_token, token_type, user_id, email }
      final token = response['access_token'] as String;
      final userId = response['user_id']?.toString() ?? '';
      final userEmail = response['email'] as String;

      await AuthService.saveToken(
        token,
        userId,
        userEmail,
        displayName: response['display_name'] as String?,
        refreshToken: response['refresh_token'] as String?,
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
      _error = _toUserFriendlyAuthError(e);
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

      // Backend returns flat: { access_token, refresh_token, token_type, user_id, email }
      final token = response['access_token'] as String;
      final userId = response['user_id']?.toString() ?? '';
      final userEmail = response['email'] as String;

      await AuthService.saveToken(
        token,
        userId,
        userEmail,
        displayName: response['display_name'] as String?,
        refreshToken: response['refresh_token'] as String?,
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
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiService.deleteAccount();
      await AuthService.logout();
      _isLoggedIn = false;
      _userId = null;
      _email = null;
      _displayName = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _toUserFriendlyAuthError(e);
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

  String _toUserFriendlyAuthError(Object error) {
    final raw = error.toString().replaceAll('Exception: ', '').trim();
    final lower = raw.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('errno = 8') ||
        lower.contains('errno = 61')) {
      return 'Connexion au service indisponible. Vérifie ton réseau et réessaie.';
    }

    if (lower.contains('existe déjà')) {
      return 'Cet e-mail est déjà utilisé. Connecte-toi ou réinitialise ton mot de passe.';
    }

    if (lower.contains('incorrect')) {
      return 'E-mail ou mot de passe incorrect.';
    }

    if (lower.contains('invalid') || lower.contains('invalide')) {
      return 'Les informations saisies sont invalides.';
    }

    return 'Action impossible pour le moment. Réessaie dans quelques instants.';
  }
}
