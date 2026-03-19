import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _requiresEmailVerification = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get requiresEmailVerification => _requiresEmailVerification;

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
      _error = _toUserFriendlyAuthError(e);
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
    _requiresEmailVerification = false;
    notifyListeners();

    try {
      final response = await ApiService.register(
        email,
        password,
        displayName: displayName,
      );

      final requiresVerification =
          response['requires_email_verification'] == true;
      final token = response['access_token'] as String?;
      final userId = response['user_id']?.toString() ?? '';
      final userEmail = response['email']?.toString() ?? email;

      if (token != null && token.isNotEmpty) {
        await AuthService.saveToken(
          token,
          userId,
          userEmail,
          displayName: response['display_name'] as String?,
          refreshToken: response['refresh_token'] as String?,
        );
        _isLoggedIn = true;
      } else {
        _isLoggedIn = false;
      }

      _requiresEmailVerification = requiresVerification;
      _userId = userId.isNotEmpty ? userId : null;
      _email = userEmail;
      _displayName = response['display_name'] as String?;
      _error = null;
      _isLoading = false;

      if (_isLoggedIn) {
        await _migrateLocalDataIfNeeded();
      }

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
    _requiresEmailVerification = false;
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
      _requiresEmailVerification = false;
      _error = null;
      _isLoading = false;

      await _migrateLocalDataIfNeeded();

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
      _requiresEmailVerification = false;
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

  Future<String?> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.requestPasswordReset(email);
      _isLoading = false;
      notifyListeners();
      final debugToken = response['debug_token'];
      return debugToken is String ? debugToken : null;
    } catch (e) {
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmPasswordReset(String token, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiService.confirmPasswordReset(token, newPassword);
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

  Future<String?> requestEmailVerification(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.requestEmailVerification(email);
      _isLoading = false;
      notifyListeners();
      final debugToken = response['debug_token'];
      return debugToken is String ? debugToken : null;
    } catch (e) {
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmEmailVerification(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiService.confirmEmailVerification(token);
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
    _requiresEmailVerification = false;
    _error = null;
    notifyListeners();
  }

  /// Migrate local anonymous data to the authenticated account.
  ///
  /// Called after a successful login or register to ensure any data
  /// created before authentication (wizard answers, preferences, etc.)
  /// is associated with the new user account for future cloud sync.
  ///
  /// Safety: captures userId at call-time to avoid race conditions
  /// if the user logs out/in rapidly. Refuses to overwrite ownership
  /// if local data already belongs to a different account.
  Future<void> _migrateLocalDataIfNeeded() async {
    final currentUserId = _userId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyMigrated =
          prefs.getBool('local_data_migrated_$currentUserId') ?? false;
      if (alreadyMigrated) return;

      // Check if local data already belongs to a different user.
      final existingOwner = prefs.getString('local_data_owner');
      if (existingOwner != null &&
          existingOwner.isNotEmpty &&
          existingOwner != currentUserId) {
        // Different user's data — do NOT overwrite ownership.
        debugPrint(
          '[AuthProvider] Local data belongs to $existingOwner, '
          'skipping migration for $currentUserId.',
        );
        return;
      }

      // Mark migration as complete — actual cloud sync will happen
      // when the sync service is implemented (post-V1).
      // For now we just tag local data with the user ID so it can
      // be associated later.
      await prefs.setString('local_data_owner', currentUserId);
      await prefs.setBool('local_data_migrated_$currentUserId', true);
    } catch (e) {
      // Migration is best-effort — never block auth flow
      debugPrint('[AuthProvider] Local data migration failed: $e');
    }
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

    if (lower.contains('registration failed') ||
        lower.contains('inscription impossible') ||
        lower.contains('service indisponible')) {
      return 'Inscription indisponible pour le moment. Utilise le mode local puis réessaie plus tard.';
    }

    if (lower.contains('authentication requise') ||
        lower.contains('unauthorized') ||
        lower.contains('forbidden')) {
      return 'Le service de compte n’est pas disponible sur cet environnement. Utilise le mode local.';
    }

    if (lower.contains('invalid') || lower.contains('invalide')) {
      return 'Les informations saisies sont invalides.';
    }
    if (lower.contains('expir')) {
      return 'Ce lien de réinitialisation a expiré. Demande un nouveau lien.';
    }
    if (lower.contains('non vérifié') || lower.contains('not verified')) {
      return 'Ton e-mail n’est pas encore vérifié. Vérifie ton e-mail puis réessaie.';
    }

    return 'Action impossible pour le moment. Réessaie dans quelques instants.';
  }
}
