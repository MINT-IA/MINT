import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Error codes for authentication operations.
///
/// The provider sets an error code; the UI layer translates it to a
/// localized message via `AppLocalizations`.
enum AuthError {
  /// Network unavailable or service unreachable.
  networkUnavailable,

  /// Email already registered.
  emailAlreadyUsed,

  /// Wrong email or password.
  incorrectCredentials,

  /// Registration temporarily unavailable.
  registrationUnavailable,

  /// Auth service not available on this environment.
  serviceUnavailable,

  /// Input data is invalid.
  invalidInput,

  /// Reset link has expired.
  linkExpired,

  /// Email not yet verified.
  emailNotVerified,

  /// Generic fallback error.
  genericError,
}

/// Translate an [AuthError] code to a localized user-facing string.
///
/// Called by UI screens (login, register, profile) to display the error.
String localizeAuthError(AuthError error, S l) {
  switch (error) {
    case AuthError.networkUnavailable:
      return l.authErrorNetwork;
    case AuthError.emailAlreadyUsed:
      return l.authErrorEmailUsed;
    case AuthError.incorrectCredentials:
      return l.authErrorIncorrect;
    case AuthError.registrationUnavailable:
      return l.authErrorRegistration;
    case AuthError.serviceUnavailable:
      return l.authErrorService;
    case AuthError.invalidInput:
      return l.authErrorInvalid;
    case AuthError.linkExpired:
      return l.authErrorExpired;
    case AuthError.emailNotVerified:
      return l.authErrorNotVerified;
    case AuthError.genericError:
      return l.authErrorGeneric;
  }
}

/// Provider for managing authentication state
/// Handles login, register, logout, and auth persistence
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userId;
  String? _email;
  String? _displayName;
  bool _isLoading = false;
  AuthError? _error;
  bool _requiresEmailVerification = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  bool get isLoading => _isLoading;
  AuthError? get error => _error;
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
        // FIX-W11-7: Set user prefix for conversation isolation.
        ConversationStore.setCurrentUserId(_userId);
        _error = null;
        // Full auth contract: migrate anonymous data, hydrate profile,
        // schedule fresh-start notifications. Required for Apple Sign-In
        // which only calls checkAuth() (not login/register).
        await _migrateLocalDataIfNeeded();
        await _hydrateProfileFromBackend();
        try {
          await FreshStartService().scheduleAllFreshStartNotifications();
        } catch (e) { debugPrint('[Auth] best-effort failed: $e'); }
      }
      // F3-2: Restore email verification state from SharedPreferences.
      // Survives cold start so the verify-email screen is shown again.
      final prefs = await SharedPreferences.getInstance();
      _requiresEmailVerification =
          prefs.getBool('requires_email_verification') ?? false;
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
        // FIX-W11-7: Set user prefix for conversation isolation.
        ConversationStore.setCurrentUserId(userId);
      } else {
        _isLoggedIn = false;
      }

      _requiresEmailVerification = requiresVerification;
      _userId = userId.isNotEmpty ? userId : null;
      _email = userEmail;
      _displayName = response['display_name'] as String?;
      _error = null;
      _isLoading = false;

      // F3-2: Persist email verification state so it survives cold start.
      if (requiresVerification) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('requires_email_verification', true);
      }

      if (_isLoggedIn) {
        await _migrateLocalDataIfNeeded();
        await _hydrateProfileFromBackend();
        // Best-effort: schedule fresh-start notifications
        try {
          await FreshStartService().scheduleAllFreshStartNotifications();
        } catch (e) { debugPrint('[Auth] best-effort failed: $e'); }
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
      // FIX-W11-7: Set user prefix for conversation isolation.
      ConversationStore.setCurrentUserId(userId);
      _requiresEmailVerification = false;
      _error = null;
      _isLoading = false;

      await _migrateLocalDataIfNeeded();
      // FIX-W11-5: Hydrate local state from backend on new device login
      await _hydrateProfileFromBackend();
      // Schedule fresh-start notifications (best-effort)
      try {
        await FreshStartService().scheduleAllFreshStartNotifications();
      } catch (_) {}

      notifyListeners();
      return true;
    } catch (e) {
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Complete Apple Sign-In flow given a verified backend response.
  ///
  /// This is the single source of truth for Apple auth state mutation.
  /// [AppleSignInService.signIn] performs the Apple handshake and backend
  /// verification but does NOT touch any state — this method owns:
  ///   1. Saving the JWT via AuthService
  ///   2. Setting _isLoggedIn, _userId, _email, _displayName
  ///   3. Setting the ConversationStore user prefix
  ///   4. Migrating local anonymous data
  ///   5. Hydrating profile from backend
  ///   6. Scheduling fresh-start notifications
  ///
  /// The response must contain `accessToken`. `userId` and `email` are
  /// optional (backend may omit them on Apple's hidden email flow).
  ///
  /// Returns `true` on success, `false` on failure (error is set).
  Future<bool> completeAppleSignIn(Map<String, dynamic> response) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final accessToken = response['accessToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Missing access token in Apple Sign-In response');
      }
      final userId = response['userId']?.toString() ?? '';
      final userEmail = response['email']?.toString() ?? '';
      final displayName = response['displayName'] as String?;
      final refreshToken = response['refreshToken'] as String?;

      // Apple Sign-In with "Hide My Email" may return an empty userId
      // or email. saveToken now throws ArgumentError on empty values
      // (Gate 0 #9 zombie-auth guard). Catch it here and surface a
      // recoverable error instead of crashing.
      if (userId.isEmpty || userEmail.isEmpty) {
        _error = AuthError.serviceUnavailable;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await AuthService.saveToken(
        accessToken,
        userId,
        userEmail,
        displayName: displayName,
        refreshToken: refreshToken,
      );

      _userId = userId.isNotEmpty ? userId : null;
      _email = userEmail;
      _displayName = displayName;
      _isLoggedIn = true;
      _requiresEmailVerification = false;
      _error = null;
      // FIX-W11-7: Set user prefix for conversation isolation.
      ConversationStore.setCurrentUserId(_userId);

      await _migrateLocalDataIfNeeded();
      await _hydrateProfileFromBackend();
      try {
        await FreshStartService().scheduleAllFreshStartNotifications();
      } catch (_) {}

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

  /// Send a magic link to the given email address.
  Future<bool> sendMagicLink(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.sendMagicLink(email);
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

  /// Verify a magic link token and complete authentication.
  Future<bool> verifyMagicLink(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.verifyMagicLink(token);

      // Backend returns camelCase: { accessToken, tokenType }
      final accessToken = (response['accessToken'] ?? response['access_token']) as String;

      // Get user info from the JWT to populate auth state.
      // For now, store the token and fetch user info separately.
      await AuthService.saveToken(
        accessToken,
        '', // userId will be populated from /me endpoint
        '', // email will be populated from /me endpoint
      );

      // Fetch user info with the new token
      try {
        final userInfo = await ApiService.getMe();
        final userId = userInfo['id']?.toString() ?? '';
        final userEmail = userInfo['email']?.toString() ?? '';
        final displayName = userInfo['display_name'] as String?;

        await AuthService.saveToken(
          accessToken,
          userId,
          userEmail,
          displayName: displayName,
        );

        _userId = userId;
        _email = userEmail;
        _displayName = displayName;
      } catch (_) {
        // Best-effort: token is valid even if /me fails
      }

      _isLoggedIn = true;
      _requiresEmailVerification = false;
      _error = null;
      _isLoading = false;

      if (_userId != null) {
        ConversationStore.setCurrentUserId(_userId);
        await _migrateLocalDataIfNeeded();
        await _hydrateProfileFromBackend();
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

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiService.deleteAccount();
      await AuthService.logout();
      // V6-4 audit fix: purge ALL local data on account deletion
      // FIX-W11-7: Clear user prefix on account deletion.
      ConversationStore.setCurrentUserId(null);
      await _purgeLocalData();
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
      // F3-2: Clear persisted verification flag on success.
      _requiresEmailVerification = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('requires_email_verification');
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

  /// Logout — V6-4 audit fix: purge ALL local data to prevent
  /// cross-account data bleed on shared devices.
  Future<void> logout() async {
    await AuthService.logout();
    // FIX-W11-7: Clear user prefix on logout.
    ConversationStore.setCurrentUserId(null);
    await _purgeLocalData();
    _isLoggedIn = false;
    _userId = null;
    _email = null;
    _displayName = null;
    _requiresEmailVerification = false;
    _error = null;
    notifyListeners();
  }

  /// V6-4 audit fix: purge ALL local data artifacts to prevent
  /// cross-account data bleed on shared devices.
  /// Same purge sequence as profile_screen.dart deleteAccount flow.
  Future<void> _purgeLocalData() async {
    // TODO(P2): Implement cloud backup of conversations/check-ins before purge
    try {
      // FIX-W11-2: Log purge scope for observability before destroying data
      // Purge conversation history
      final store = ConversationStore();
      final conversations = await store.listConversations();
      debugPrint(
        '[Auth] Purging ${conversations.length} conversations (not backed up)',
      );
      for (final conv in conversations) {
        await store.deleteConversation(conv.id);
      }
      // Purge coach memory (insights)
      await CoachMemoryService.clear();
      // Purge CapEngine memory
      await CapMemoryStore.clear();
      // Purge analytics queue
      await AnalyticsService().clearLocalQueue();
      // F2: Purge BYOK API keys from secure storage (prevents cross-account key bleed)
      const secureStorage = FlutterSecureStorage();
      await secureStorage.deleteAll();
      // Clear account-specific SharedPreferences while preserving device prefs.
      // Save device-level prefs, clear everything, then restore them.
      // This is safer than selective removal (new keys are auto-cleared).
      // See SOURCE_OF_TRUTH_MATRIX.md §6 for governance.
      final prefs = await SharedPreferences.getInstance();
      await PrecomputedInsightsService.clear(prefs);
      // Preserve device-level preferences across logout
      final preservedLocale = prefs.getString('mint_locale');
      final preservedB2bOrg = prefs.getString('_b2b_organization');
      final preservedWhiteLabel = prefs.getString('_white_label_config');
      await prefs.clear();
      // Restore device-level preferences
      if (preservedLocale != null) {
        await prefs.setString('mint_locale', preservedLocale);
      }
      if (preservedB2bOrg != null) {
        await prefs.setString('_b2b_organization', preservedB2bOrg);
      }
      if (preservedWhiteLabel != null) {
        await prefs.setString('_white_label_config', preservedWhiteLabel);
      }
    } catch (e) {
      // Purge is best-effort — never block auth flow
      if (kDebugMode) {
        debugPrint('[AuthProvider] Local data purge failed: $e');
      }
    }
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
        // PRIVACY: never log raw user IDs — redact to first 4 chars only.
        if (kDebugMode) {
          final ownerTag = existingOwner.length > 4
              ? '${existingOwner.substring(0, 4)}…'
              : '****';
          debugPrint(
            '[AuthProvider] Local data belongs to different user ($ownerTag), '
            'skipping migration.',
          );
        }
        return;
      }

      // Migrate anonymous conversations to authenticated user namespace.
      // Must happen before wizard data push so conversation history is preserved.
      try {
        await ConversationStore.migrateAnonymousToUser(currentUserId);
        await AnonymousSessionService.clearSession();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthProvider] Anonymous conversation migration failed: $e');
        }
      }

      // Push local wizard data to backend via claimLocalData.
      // Best-effort: failure does not block the auth flow.
      try {
        final answers = await ReportPersistenceService.loadAnswers();
        if (answers.isNotEmpty) {
          var deviceId = prefs.getString('_mint_device_id');
          if (deviceId == null) {
            deviceId = const Uuid().v4();
            await prefs.setString('_mint_device_id', deviceId);
          }
          await ApiService.claimLocalData(
            localDataVersion: 1,
            deviceId: deviceId,
            wizardAnswers: answers,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthProvider] claimLocalData sync failed: $e');
        }
      }

      await prefs.setString('local_data_owner', currentUserId);
      await prefs.setBool('local_data_migrated_$currentUserId', true);
    } catch (e) {
      // Migration is best-effort — never block auth flow
      if (kDebugMode) debugPrint('[AuthProvider] Local data migration failed: $e');
    }
  }

  /// FIX-W11-5: Hydrate key profile fields from backend on login.
  ///
  /// On a new device the local SharedPreferences are empty. This fetches
  /// the cloud profile and seeds the most critical fields so screens
  /// don't show an empty state.
  Future<void> _hydrateProfileFromBackend() async {
    try {
      final profileData = await ApiService.get('/profiles/me');
      if (profileData.isEmpty) return;
      final data = profileData['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final prefs = await SharedPreferences.getInstance();
      if (data['birthYear'] != null) {
        await prefs.setInt('q_birth_year', data['birthYear'] as int);
      }
      if (data['canton'] != null) {
        await prefs.setString('q_canton', data['canton'] as String);
      }
      if (data['incomeGrossYearly'] != null) {
        await prefs.setDouble(
          'q_gross_salary',
          (data['incomeGrossYearly'] as num).toDouble() / 12,
        );
      }
      if (data['incomeNetMonthly'] != null) {
        await prefs.setDouble(
          'q_net_income_period_chf',
          (data['incomeNetMonthly'] as num).toDouble(),
        );
      }
      if (data['householdType'] != null) {
        await prefs.setString(
          'q_household_type',
          data['householdType'] as String,
        );
      }
    } catch (e) {
      // Hydration is best-effort — never block login flow
      if (kDebugMode) {
        debugPrint('[AuthProvider] Profile hydration failed: $e');
      }
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  AuthError _toUserFriendlyAuthError(Object error) {
    final raw = error.toString().replaceAll('Exception: ', '').trim();
    final lower = raw.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('errno = 8') ||
        lower.contains('errno = 61')) {
      return AuthError.networkUnavailable;
    }

    if (lower.contains('existe déjà')) {
      return AuthError.emailAlreadyUsed;
    }

    if (lower.contains('incorrect')) {
      return AuthError.incorrectCredentials;
    }

    if (lower.contains('registration failed') ||
        lower.contains('inscription impossible') ||
        lower.contains('service indisponible')) {
      return AuthError.registrationUnavailable;
    }

    if (lower.contains('authentication requise') ||
        lower.contains('unauthorized') ||
        lower.contains('forbidden')) {
      return AuthError.serviceUnavailable;
    }

    if (lower.contains('invalid') || lower.contains('invalide')) {
      return AuthError.invalidInput;
    }
    if (lower.contains('expir')) {
      return AuthError.linkExpired;
    }
    if (lower.contains('non vérifié') || lower.contains('not verified')) {
      return AuthError.emailNotVerified;
    }

    return AuthError.genericError;
  }
}
