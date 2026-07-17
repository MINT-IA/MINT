import 'package:flutter/foundation.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/pending_auth_identity_store.dart';
import 'package:mint_mobile/services/local_data_claim_attempt_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
import 'package:mint_mobile/services/session_epoch.dart';

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

enum AuthProfileAnswerTrust { userInput, backendUnknown }

typedef AuthProfileAnswerWriter = Future<void> Function(
  Map<String, dynamic> answers,
  AuthProfileAnswerTrust trust,
  SessionEpochGuard sessionGuard,
);

/// Provider for managing authentication state
/// Handles login, register, logout, and auth persistence
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    SessionTerminationCoordinator? sessionTerminationCoordinator,
    PartnerAccountabilityBindingStore? partnerAccountabilityBindingStore,
    Future<void> Function()? logoutAction,
    Future<void> Function()? deleteAccountAction,
    Future<void> Function()? bestEffortLocalDataPurge,
    Future<Map<String, dynamic>> Function(String, String)? loginAction,
    Future<Map<String, dynamic>> Function(
      String,
      String, {
      String? displayName,
    })? registerAction,
    Future<Map<String, dynamic>> Function()? profileHydrationAction,
    Future<void> Function(String)? sendMagicLinkAction,
    Future<Map<String, dynamic>> Function(String)? verifyMagicLinkAction,
    Future<Map<String, dynamic>> Function(String)? magicLinkProfileAction,
    Future<bool> Function()? initialAuthAction,
    AuthProfileAnswerWriter? profileAnswerWriter,
    Future<Map<String, dynamic>> Function()? localDataAnswersReader,
    PendingAuthIdentityStore pendingAuthIdentityStore =
        const PendingAuthIdentityStore(),
    LocalDataClaimAttemptStore localDataClaimAttemptStore =
        const LocalDataClaimAttemptStore(),
  })  : _ownsSessionTerminationCoordinator =
            sessionTerminationCoordinator == null,
        _sessionTerminationCoordinator = sessionTerminationCoordinator ??
            SessionTerminationCoordinator.standalone(
              partnerAccountabilityBindingStore:
                  partnerAccountabilityBindingStore,
              clearAuthTokens: logoutAction,
              bestEffortLocalDataPurge: bestEffortLocalDataPurge,
            ),
        _deleteAccountAction = deleteAccountAction ?? ApiService.deleteAccount,
        _loginAction = loginAction ?? ApiService.login,
        _registerAction = registerAction ?? ApiService.register,
        _profileHydrationAction =
            profileHydrationAction ?? (() => ApiService.get('/profiles/me')),
        _sendMagicLinkAction = sendMagicLinkAction ?? ApiService.sendMagicLink,
        _verifyMagicLinkAction =
            verifyMagicLinkAction ?? ApiService.verifyMagicLink,
        _magicLinkProfileAction =
            magicLinkProfileAction ?? ApiService.getMeWithEphemeralAccessToken,
        _initialAuthAction = initialAuthAction ?? AuthService.isLoggedIn,
        _profileAnswerWriter = profileAnswerWriter,
        _pendingAuthIdentityStore = pendingAuthIdentityStore,
        _localDataClaimAttemptStore = localDataClaimAttemptStore,
        _localDataAnswersReader =
            localDataAnswersReader ?? ReportPersistenceService.loadAnswers {
    _sessionEpoch = _sessionTerminationCoordinator.sessionEpoch;
  }

  final SessionTerminationCoordinator _sessionTerminationCoordinator;
  final bool _ownsSessionTerminationCoordinator;
  final Future<void> Function() _deleteAccountAction;
  final Future<Map<String, dynamic>> Function(String, String) _loginAction;
  final Future<Map<String, dynamic>> Function(
    String,
    String, {
    String? displayName,
  }) _registerAction;
  final Future<Map<String, dynamic>> Function() _profileHydrationAction;
  final Future<void> Function(String) _sendMagicLinkAction;
  final Future<Map<String, dynamic>> Function(String) _verifyMagicLinkAction;
  final Future<Map<String, dynamic>> Function(String) _magicLinkProfileAction;
  final Future<bool> Function() _initialAuthAction;
  final AuthProfileAnswerWriter? _profileAnswerWriter;
  final PendingAuthIdentityStore _pendingAuthIdentityStore;
  final LocalDataClaimAttemptStore _localDataClaimAttemptStore;
  final Future<Map<String, dynamic>> Function() _localDataAnswersReader;
  late final SessionEpoch _sessionEpoch;
  ApiSessionTerminationBinding? _apiSessionTerminationBinding;

  bool _isLoggedIn = false;
  String? _userId;
  String? _email;
  String? _displayName;
  bool _isLoading = false;
  AuthError? _error;
  bool _requiresEmailVerification = false;
  bool _isSessionTerminationBlocked = false;
  Future<void>? _sessionTerminationFuture;
  bool _disposed = false;
  Object? _identityEntryToken;
  int? _identityEntryGeneration;
  PendingAuthIdentity? _pendingAuthIdentity;
  bool _hasCompletedInitialAuthCheck = false;
  // Local-mode default-on: the router's "authenticated" scope passes when
  // `isLoggedIn || isLocalMode`. Starting true keeps tab navigation alive
  // even if `checkAuth()` throws before the prefs block runs (e.g. on a
  // keychain failure). `register()`/`login()` explicitly flip this to false.
  bool _isLocalMode = true;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  bool get isLoading => _isLoading;
  AuthError? get error => _error;
  bool get requiresEmailVerification => _requiresEmailVerification;
  bool get isLocalMode => _isLocalMode;
  bool get isSessionTerminationBlocked => _isSessionTerminationBlocked;
  bool get hasCompletedInitialAuthCheck => _hasCompletedInitialAuthCheck;

  Future<Object?> _beginIdentityEntry({
    String? candidateEmail,
    String? candidateUserId,
  }) async {
    try {
      final guard = _sessionEpoch.capture();
      final pending = await _sessionEpoch.runGuardedPersistence(
        guard,
        _pendingAuthIdentityStore.load,
      );
      guard.assertCurrent();
      _pendingAuthIdentity = pending;
      if (pending != null &&
          candidateEmail != null &&
          !await _pendingAuthIdentityStore.matches(
            pending,
            email: candidateEmail,
            userId: candidateUserId,
          )) {
        _rejectPendingIdentityMismatch();
        return null;
      }
      guard.assertCurrent();
    } on SessionEpochInvalidated {
      return null;
    } on Object {
      _rejectPendingIdentityMismatch();
      return null;
    }
    final generation = _sessionEpoch.generation;
    if (_identityEntryToken != null && _identityEntryGeneration == generation) {
      return null;
    }
    if (_rejectSessionEntryWhileTerminating() ||
        _rejectAuthenticatedSessionEntry()) {
      return null;
    }
    final token = Object();
    _identityEntryToken = token;
    _identityEntryGeneration = generation;
    return token;
  }

  void _rejectPendingIdentityMismatch() {
    _isLoading = false;
    _error = AuthError.serviceUnavailable;
    if (!_disposed) notifyListeners();
  }

  void _endIdentityEntry(Object token) {
    if (!identical(_identityEntryToken, token)) return;
    _identityEntryToken = null;
    _identityEntryGeneration = null;
  }

  /// Binds terminal API 401 handling to this exact app-owned auth provider.
  /// MintApp calls this once after constructing the full provider graph.
  void bindApiSessionTermination() {
    if (_apiSessionTerminationBinding != null) return;
    _apiSessionTerminationBinding = ApiService.bindSessionTerminationHandler(
      handleTerminalSessionExpiry,
      sessionEpoch: _sessionEpoch,
    );
  }

  /// Check stored auth on app startup
  Future<void> checkAuth() async {
    if (_isSessionTerminationBlocked) return;
    _isLoading = true;
    notifyListeners();

    SessionEpochGuard? guard;
    try {
      await _sessionTerminationCoordinator.resumePendingTerminationIfNeeded();
      guard = _sessionEpoch.capture();
      PendingAuthIdentity? pendingIdentity;
      try {
        pendingIdentity = await _sessionEpoch.runGuardedPersistence(
          guard,
          _pendingAuthIdentityStore.load,
        );
      } on SessionEpochInvalidated {
        rethrow;
      } on Object {
        // An unreadable marker is evidence of an incomplete identity
        // transaction, never a virgin install. Purge before resolving auth.
        guard = null;
        await _terminateSession();
        guard = _sessionEpoch.capture();
        pendingIdentity = null;
      }
      guard.assertCurrent();
      _pendingAuthIdentity = pendingIdentity;
      var isLoggedIn = false;
      List<String?>? storedIdentity;
      try {
        isLoggedIn = await _initialAuthAction();
        guard.assertCurrent();
        if (isLoggedIn) {
          storedIdentity = await Future.wait<String?>([
            AuthService.getUserId(),
            AuthService.getUserEmail(),
            AuthService.getDisplayName(),
          ]);
        }
      } on AuthSessionRecoveryRequired {
        // A corrupt authority is neither logged-in nor a virgin anonymous
        // install. Invalidate A synchronously, await the same terminal purge
        // as logout/401, then resume this cold check in the reopened epoch.
        guard = null;
        await _terminateSession();
        guard = _sessionEpoch.capture();
        isLoggedIn = false;
      }
      guard.assertCurrent();
      if (isLoggedIn) {
        final pending = _pendingAuthIdentity;
        final storedUserId = storedIdentity![0];
        final storedEmail = storedIdentity[1];
        final pendingIdentityMismatch = pending != null &&
            (storedUserId == null ||
                storedUserId.isEmpty ||
                storedEmail == null ||
                !await _pendingAuthIdentityStore.matches(
                  pending,
                  email: storedEmail,
                  userId: storedUserId,
                ));
        if (pendingIdentityMismatch) {
          // A crash can leave token B beside pending anonymous facts for A.
          // Purge the mixed authority before any ledger read or publication.
          guard = null;
          await _terminateSession();
          guard = _sessionEpoch.capture();
          isLoggedIn = false;
        } else {
          guard.assertCurrent();
          _userId = storedIdentity[0];
          _email = storedIdentity[1];
          _displayName = storedIdentity[2];
          _isLoggedIn = true;
          // FIX-W11-7: Set user prefix for conversation isolation.
          ConversationStore.setCurrentUserId(_userId);
          _error = null;
          // Full auth contract: migrate anonymous data, hydrate profile,
          // schedule fresh-start notifications. Required for Apple Sign-In
          // which only calls checkAuth() (not login/register).
          await _migrateLocalDataIfNeeded(guard);
          await _hydrateProfileFromBackend(guard);
          if (storedEmail != null &&
              storedUserId != null &&
              storedUserId.isNotEmpty) {
            await _releasePendingIdentityIfMigrated(
              guard,
              email: storedEmail,
              userId: storedUserId,
            );
          }
          try {
            await _scheduleFreshStartNotifications(guard);
          } catch (_) {
            debugPrint('[Auth] best-effort failed');
          }
        }
      }
      // F3-2: Restore email verification state from SharedPreferences.
      // Survives cold start so the verify-email screen is shown again.
      final prefs = await SharedPreferences.getInstance();
      _requiresEmailVerification =
          prefs.getBool('requires_email_verification') ?? false;
      // Local-mode default: true on fresh install.
      // Explicit register/login flips it to false.
      if (!prefs.containsKey('auth_local_mode')) {
        await _sessionEpoch.runGuardedPersistence(
          guard,
          () async {
            await prefs.setBool('auth_local_mode', true);
          },
        );
      }
      guard.assertCurrent();
      _isLocalMode = prefs.getBool('auth_local_mode') ?? true;
      _hasCompletedInitialAuthCheck = true;
    } on SessionEpochInvalidated {
      // The termination transaction owns all state from this point.
    } catch (e) {
      if (guard != null && !_isCurrent(guard)) return;
      _error = _toUserFriendlyAuthError(e);
      _isSessionTerminationBlocked = _isSessionTerminationBlocked ||
          _sessionTerminationCoordinator.isBlocked;
    } finally {
      var current = false;
      try {
        guard?.assertCurrent();
        current = guard != null;
      } on SessionEpochInvalidated {
        current = false;
      }
      if (!_isSessionTerminationBlocked && current) {
        _isLoading = false;
        if (!_disposed) notifyListeners();
      } else if (_isSessionTerminationBlocked && !_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Register new user
  Future<bool> register(
    String email,
    String password, {
    String? displayName,
    DateTime? dateOfBirth,
  }) async {
    final identityEntry = await _beginIdentityEntry(candidateEmail: email);
    if (identityEntry == null) return false;
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    _requiresEmailVerification = false;
    notifyListeners();

    try {
      final registrationAnswers = <String, dynamic>{
        if (displayName != null && displayName.trim().isNotEmpty)
          'q_firstname': displayName.trim(),
        if (dateOfBirth != null) ...{
          'q_birth_year': dateOfBirth.year,
          'q_date_of_birth': _formatCivilDate(dateOfBirth),
        },
      };
      await _bindPendingIdentity(guard, email: email);
      if (registrationAnswers.isNotEmpty) {
        await _writeProfileAnswers(
          guard,
          registrationAnswers,
          trust: AuthProfileAnswerTrust.userInput,
        );
      }
      guard.assertCurrent();

      final response = await _registerAction(
        email,
        password,
        displayName: displayName,
      );
      guard.assertCurrent();

      final requiresVerification =
          response['requires_email_verification'] == true;
      final token = response['access_token'] as String?;
      final userId = response['user_id']?.toString() ?? '';
      final userEmail = response['email']?.toString() ?? email;
      _assertRequestedIdentity(
        requestedEmail: email,
        resolvedEmail: userEmail,
      );
      await _bindResolvedPendingIdentity(
        guard,
        email: userEmail,
        userId: userId,
      );

      if (token != null && token.isNotEmpty) {
        await _sessionEpoch.runGuardedPersistence(
          guard,
          () async {
            await AuthService.saveToken(
              token,
              userId,
              userEmail,
              displayName: response['display_name'] as String?,
              refreshToken: response['refresh_token'] as String?,
            );
            await (await SharedPreferences.getInstance())
                .setBool('auth_local_mode', false);
          },
        );
        guard.assertCurrent();
        _isLoggedIn = true;
        _isLocalMode = false;
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
        await _sessionEpoch.runGuardedPersistence(
          guard,
          () async {
            await prefs.setBool('requires_email_verification', true);
          },
        );
      }

      if (_isLoggedIn) {
        await _migrateLocalDataIfNeeded(guard);
        await _hydrateProfileFromBackend(guard);
        await _releasePendingIdentityIfMigrated(
          guard,
          email: userEmail,
          userId: userId,
        );
        // Best-effort: schedule fresh-start notifications
        try {
          await _scheduleFreshStartNotifications(guard);
        } catch (_) {
          debugPrint('[Auth] best-effort failed');
        }
      }

      guard.assertCurrent();
      if (!_disposed) notifyListeners();
      return true;
    } on SessionEpochInvalidated {
      return false;
    } catch (e) {
      if (!_isCurrent(guard)) return false;
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _endIdentityEntry(identityEntry);
    }
  }

  /// Login
  Future<bool> login(String email, String password) async {
    final identityEntry = await _beginIdentityEntry(candidateEmail: email);
    if (identityEntry == null) return false;
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    _requiresEmailVerification = false;
    notifyListeners();

    try {
      final response = await _loginAction(email, password);
      guard.assertCurrent();

      // Backend returns flat: { access_token, refresh_token, token_type, user_id, email }
      final token = response['access_token'] as String;
      final userId = response['user_id']?.toString() ?? '';
      final userEmail = response['email'] as String;
      _assertRequestedIdentity(
        requestedEmail: email,
        resolvedEmail: userEmail,
      );
      await _bindResolvedPendingIdentity(
        guard,
        email: userEmail,
        userId: userId,
      );

      await _sessionEpoch.runGuardedPersistence(
        guard,
        () async {
          await AuthService.saveToken(
            token,
            userId,
            userEmail,
            displayName: response['display_name'] as String?,
            refreshToken: response['refresh_token'] as String?,
          );
          await (await SharedPreferences.getInstance())
              .setBool('auth_local_mode', false);
        },
      );
      guard.assertCurrent();

      _userId = userId;
      _email = userEmail;
      _displayName = response['display_name'] as String?;
      _isLoggedIn = true;
      _isLocalMode = false;
      // FIX-W11-7: Set user prefix for conversation isolation.
      ConversationStore.setCurrentUserId(userId);
      _requiresEmailVerification = false;
      _error = null;
      _isLoading = false;

      await _migrateLocalDataIfNeeded(guard);
      // FIX-W11-5: Hydrate local state from backend on new device login
      await _hydrateProfileFromBackend(guard);
      await _releasePendingIdentityIfMigrated(
        guard,
        email: userEmail,
        userId: userId,
      );
      // Schedule fresh-start notifications (best-effort)
      try {
        await _scheduleFreshStartNotifications(guard);
      } catch (_) {}

      guard.assertCurrent();
      if (!_disposed) notifyListeners();
      return true;
    } on SessionEpochInvalidated {
      return false;
    } catch (e) {
      if (!_isCurrent(guard)) return false;
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _endIdentityEntry(identityEntry);
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
    final accessToken = response['accessToken'] as String?;
    final userId = response['userId']?.toString() ?? '';
    final userEmail = response['email']?.toString() ?? '';
    final displayName = response['displayName'] as String?;
    final refreshToken = response['refreshToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      _error = AuthError.serviceUnavailable;
      if (!_disposed) notifyListeners();
      return false;
    }
    if (userId.isEmpty || userEmail.isEmpty) {
      _error = AuthError.serviceUnavailable;
      if (!_disposed) notifyListeners();
      return false;
    }
    final identityEntry = await _beginIdentityEntry(
      candidateEmail: userEmail,
      candidateUserId: userId,
    );
    if (identityEntry == null) return false;
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      guard.assertCurrent();

      await _bindResolvedPendingIdentity(
        guard,
        email: userEmail,
        userId: userId,
      );

      await _sessionEpoch.runGuardedPersistence(
        guard,
        () async {
          await AuthService.saveToken(
            accessToken,
            userId,
            userEmail,
            displayName: displayName,
            refreshToken: refreshToken,
          );
          await (await SharedPreferences.getInstance())
              .setBool('auth_local_mode', false);
        },
      );
      guard.assertCurrent();

      _userId = userId.isNotEmpty ? userId : null;
      _email = userEmail;
      _displayName = displayName;
      _isLoggedIn = true;
      _isLocalMode = false;
      _requiresEmailVerification = false;
      _error = null;
      // FIX-W11-7: Set user prefix for conversation isolation.
      ConversationStore.setCurrentUserId(_userId);

      await _migrateLocalDataIfNeeded(guard);
      await _hydrateProfileFromBackend(guard);
      await _releasePendingIdentityIfMigrated(
        guard,
        email: userEmail,
        userId: userId,
      );
      try {
        await _scheduleFreshStartNotifications(guard);
      } catch (_) {}

      _isLoading = false;
      guard.assertCurrent();
      if (!_disposed) notifyListeners();
      return true;
    } on SessionEpochInvalidated {
      return false;
    } catch (e) {
      if (!_isCurrent(guard)) return false;
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _endIdentityEntry(identityEntry);
    }
  }

  /// Send a magic link to the given email address.
  Future<bool> sendMagicLink(String email) async {
    if (_rejectSessionEntryWhileTerminating()) return false;
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _sendMagicLinkAction(email);
      guard.assertCurrent();
      _isLoading = false;
      notifyListeners();
      return true;
    } on SessionEpochInvalidated {
      return false;
    } catch (e) {
      if (!_isCurrent(guard)) return false;
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify a magic link token and complete authentication.
  Future<bool> verifyMagicLink(String token) async {
    final identityEntry = await _beginIdentityEntry();
    if (identityEntry == null) return false;
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _verifyMagicLinkAction(token);
      guard.assertCurrent();

      final rawAccessToken =
          response['accessToken'] ?? response['access_token'];
      if (rawAccessToken is! String || rawAccessToken.trim().isEmpty) {
        throw StateError('Magic-link response has no access token');
      }
      final accessToken = rawAccessToken;
      final userInfo = await _magicLinkProfileAction(accessToken);
      guard.assertCurrent();
      final userId =
          (userInfo['id'] ?? userInfo['user_id'])?.toString().trim() ?? '';
      final userEmail = userInfo['email']?.toString().trim() ?? '';
      if (userId.isEmpty || userEmail.isEmpty) {
        throw StateError('Magic-link identity is incomplete');
      }
      final displayName =
          (userInfo['display_name'] ?? userInfo['displayName']) as String?;
      final rawRefreshToken =
          response['refreshToken'] ?? response['refresh_token'];
      final refreshToken =
          rawRefreshToken is String && rawRefreshToken.trim().isNotEmpty
              ? rawRefreshToken
              : null;

      await _bindResolvedPendingIdentity(
        guard,
        email: userEmail,
        userId: userId,
      );

      await _sessionEpoch.runGuardedPersistence(
        guard,
        () async {
          await AuthService.saveToken(
            accessToken,
            userId,
            userEmail,
            displayName: displayName,
            refreshToken: refreshToken,
          );
          await (await SharedPreferences.getInstance())
              .setBool('auth_local_mode', false);
        },
      );
      guard.assertCurrent();

      _userId = userId;
      _email = userEmail;
      _displayName = displayName;
      _isLoggedIn = true;
      _isLocalMode = false;
      _requiresEmailVerification = false;
      _error = null;
      _isLoading = false;

      ConversationStore.setCurrentUserId(_userId);
      await _migrateLocalDataIfNeeded(guard);
      await _hydrateProfileFromBackend(guard);
      await _releasePendingIdentityIfMigrated(
        guard,
        email: userEmail,
        userId: userId,
      );

      guard.assertCurrent();
      if (!_disposed) notifyListeners();
      return true;
    } on SessionEpochInvalidated {
      return false;
    } catch (e) {
      if (!_isCurrent(guard)) return false;
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _endIdentityEntry(identityEntry);
    }
  }

  Future<bool> deleteAccount() async {
    if (_rejectSessionEntryWhileTerminating()) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _deleteAccountAction();
      await _terminateSession();
      return true;
    } catch (e) {
      if (_isSessionTerminationBlocked) return false;
      _error = _toUserFriendlyAuthError(e);
      _isLoading = false;
      if (!_disposed) notifyListeners();
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

  /// Explicit account exit. Terminal API expiry calls the same transaction.
  Future<void> logout() => _terminateSession();

  /// Awaitable callback injected into [ApiService] by MintApp.
  Future<void> handleTerminalSessionExpiry() => _terminateSession();

  Future<void> _terminateSession() {
    final existing = _sessionTerminationFuture;
    if (existing != null) return existing;

    // This call invalidates the shared epoch synchronously before provider
    // callbacks or any other asynchronous work can run.
    final termination = _sessionTerminationCoordinator.terminate();
    _isSessionTerminationBlocked = true;
    _isLoading = true;
    _isLocalMode = false;
    _error = null;
    if (!_disposed) notifyListeners();

    late final Future<void> operation;
    operation = _performSessionTermination(termination).whenComplete(() {
      if (identical(_sessionTerminationFuture, operation)) {
        _sessionTerminationFuture = null;
      }
    });
    _sessionTerminationFuture = operation;
    return operation;
  }

  Future<void> _performSessionTermination(Future<void> termination) async {
    try {
      await termination;
      await _pendingAuthIdentityStore.clear();
      await _localDataClaimAttemptStore.clear();
      if (_disposed) {
        throw StateError('Auth provider disposed during session termination');
      }
      ConversationStore.setCurrentUserId(null);
      _pendingAuthIdentity = null;
      _clearAuthenticatedIdentity();
      _isSessionTerminationBlocked = false;
      _isLoading = false;
      _error = null;
      notifyListeners();
    } on Object {
      if (!_disposed) {
        _isLoading = false;
        _isSessionTerminationBlocked = true;
        _error = AuthError.serviceUnavailable;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _clearAuthenticatedIdentity() {
    _isLoggedIn = false;
    _userId = null;
    _email = null;
    _displayName = null;
    _requiresEmailVerification = false;
    _isLocalMode = false;
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
  Future<void> _migrateLocalDataIfNeeded(SessionEpochGuard guard) async {
    final currentUserId = _userId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      guard.assertCurrent();
      final alreadyMigrated =
          prefs.getBool('local_data_migrated_$currentUserId') ?? false;
      if (alreadyMigrated) return;

      // Check if local data already belongs to a different user.
      final existingOwner = prefs.getString('local_data_owner');
      if (existingOwner != null &&
          existingOwner.isNotEmpty &&
          existingOwner != currentUserId) {
        // Different user's data — do NOT overwrite ownership.
        // PRIVACY: never log raw or partial user identifiers.
        if (kDebugMode) {
          debugPrint(
            '[AuthProvider] Local data belongs to a different user; '
            'skipping migration.',
          );
        }
        return;
      }

      // Reserve the anonymous ledger for this exact account before any claim
      // payload is read. A failed claim remains retryable by A while B stays
      // unable to inherit or upload A's local facts.
      await _sessionEpoch.runGuardedPersistence(
        guard,
        () async {
          final written = await prefs.setString(
            'local_data_owner',
            currentUserId,
          );
          if (!written ||
              prefs.getString('local_data_owner') != currentUserId) {
            throw StateError('Local data owner reservation failed');
          }
        },
      );
      guard.assertCurrent();

      // Migrate anonymous conversations to authenticated user namespace.
      // Must happen before wizard data push so conversation history is preserved.
      try {
        await ConversationStore.migrateAnonymousToUser(currentUserId);
        await AnonymousSessionService.clearSession();
        guard.assertCurrent();
      } on SessionEpochInvalidated {
        rethrow;
      } catch (_) {
        if (kDebugMode) {
          debugPrint('[AuthProvider] Anonymous conversation migration failed');
        }
      }

      // Push local wizard data to backend via claimLocalData.
      // Best-effort: failure does not block the auth flow.
      LocalDataClaimAttempt? completedClaimAttempt;
      try {
        final operation = ApiService.authenticatedTransport.beginOperation();
        await operation.requireSession();
        guard.assertCurrent();
        final answers = await _localDataAnswersReader();
        guard.assertCurrent();
        if (answers.isNotEmpty) {
          final backendAnswers =
              ReportPersistenceService.backendSafeAnswers(answers);
          var deviceId = prefs.getString('_mint_device_id');
          if (deviceId == null) {
            deviceId = const Uuid().v4();
            await _sessionEpoch.runGuardedPersistence(
              guard,
              () async {
                final deviceIdWritten =
                    await prefs.setString('_mint_device_id', deviceId!);
                if (!deviceIdWritten ||
                    prefs.getString('_mint_device_id') != deviceId) {
                  throw StateError('Claim device id commit failed');
                }
              },
            );
          }
          final claimAttempt = await _sessionEpoch.runGuardedPersistence(
            guard,
            () => _localDataClaimAttemptStore.resolve(
              deviceId: deviceId!,
              payload: _claimSemanticPayload(backendAnswers),
            ),
          );
          guard.assertCurrent();
          await ApiService.claimLocalData(
            localDataVersion: 1,
            deviceId: deviceId,
            updatedAt: claimAttempt.updatedAt,
            wizardAnswers: backendAnswers,
            operation: operation,
          );
          guard.assertCurrent();
          final latestAnswers = await _localDataAnswersReader();
          guard.assertCurrent();
          final latestAttempt = await _sessionEpoch.runGuardedPersistence(
            guard,
            () => _localDataClaimAttemptStore.resolve(
              deviceId: deviceId!,
              payload: _claimSemanticPayload(
                ReportPersistenceService.backendSafeAnswers(latestAnswers),
              ),
            ),
          );
          guard.assertCurrent();
          if (latestAttempt.payloadFingerprint !=
              claimAttempt.payloadFingerprint) {
            return;
          }
          completedClaimAttempt = claimAttempt;
        }
      } on SessionEpochInvalidated {
        rethrow;
      } catch (_) {
        if (kDebugMode) {
          debugPrint('[AuthProvider] claimLocalData sync failed');
        }
        return;
      }

      await _sessionEpoch.runGuardedPersistence(
        guard,
        () async {
          final key = 'local_data_migrated_$currentUserId';
          final written = await prefs.setBool(key, true);
          if (!written || prefs.getBool(key) != true) {
            throw StateError('Local data migration commit failed');
          }
        },
      );
      final claimAttempt = completedClaimAttempt;
      if (claimAttempt != null) {
        await _sessionEpoch.runGuardedPersistence(
          guard,
          () => _localDataClaimAttemptStore.clearMatching(claimAttempt),
        );
      }
    } on SessionEpochInvalidated {
      rethrow;
    } catch (_) {
      // Migration is best-effort — never block auth flow
      if (kDebugMode) {
        debugPrint('[AuthProvider] Local data migration failed');
      }
    }
  }

  static Map<String, dynamic> _claimSemanticPayload(
    Map<String, dynamic> wizardAnswers,
  ) =>
      {
        'local_data_version': 1,
        'wizard_answers': wizardAnswers,
        'mini_onboarding': const <String, dynamic>{},
        'budget_snapshot': const <String, dynamic>{},
        'checkins': const <Map<String, dynamic>>[],
      };

  /// FIX-W11-5: Hydrate key profile fields from backend on login.
  ///
  /// On a new device the local SharedPreferences are empty. This fetches
  /// the cloud profile and seeds the most critical fields so screens
  /// don't show an empty state.
  Future<void> _hydrateProfileFromBackend(SessionEpochGuard guard) async {
    try {
      final profileData = await _profileHydrationAction();
      guard.assertCurrent();
      if (profileData.isEmpty) return;
      const backendProfileKeys = <String>{
        'birthYear',
        'canton',
        'gender',
        'incomeGrossYearly',
        'incomeNetMonthly',
        'employmentStatus',
        'householdType',
        'avoirLpp',
        'lppInsuredSalary',
        'lppBuybackMax',
        'pillar3aBalance',
      };
      final nested = profileData['data'];
      final hasDirectShape = backendProfileKeys.any(profileData.containsKey);
      final data = hasDirectShape
          ? profileData
          : nested is Map
              ? Map<String, dynamic>.from(nested)
              : const <String, dynamic>{};
      if (data.isEmpty) return;

      final writer = _profileAnswerWriter;
      if (writer != null) {
        await writer(
          Map<String, dynamic>.from(data),
          AuthProfileAnswerTrust.backendUnknown,
          guard,
        );
        guard.assertCurrent();
        return;
      }

      final partial = <String, dynamic>{};
      final rawBirthYear = data['birthYear'];
      if (rawBirthYear is num &&
          rawBirthYear.toDouble().isFinite &&
          rawBirthYear.toDouble() == rawBirthYear.toInt().toDouble()) {
        partial['q_birth_year'] = rawBirthYear.toInt();
      }
      if (data['canton'] is String) {
        partial['q_canton'] = data['canton'];
      }
      if (data['gender'] is String) {
        partial['q_gender'] = data['gender'];
      }
      if (data['incomeGrossYearly'] is num) {
        partial['q_gross_salary_annual'] =
            (data['incomeGrossYearly'] as num).toDouble();
      }
      if (data['incomeNetMonthly'] is num) {
        partial['q_net_income_period_chf'] =
            (data['incomeNetMonthly'] as num).toDouble();
        partial['q_pay_frequency'] = 'monthly';
      }
      if (data['employmentStatus'] is String) {
        partial['q_employment_status'] = data['employmentStatus'];
      }
      if (data['householdType'] is String) {
        partial['q_household_type'] = data['householdType'];
      }
      if (data['avoirLpp'] is num) {
        partial['_coach_avoir_lpp'] = (data['avoirLpp'] as num).toDouble();
      }
      if (data['lppInsuredSalary'] is num) {
        partial['_coach_salaire_assure'] =
            (data['lppInsuredSalary'] as num).toDouble();
      }
      if (data['lppBuybackMax'] is num) {
        partial['_coach_rachat_maximum'] =
            (data['lppBuybackMax'] as num).toDouble();
      }
      if (data['pillar3aBalance'] is num) {
        partial['q_3a_total'] = (data['pillar3aBalance'] as num).toDouble();
      }
      if (partial.isNotEmpty) {
        await _writeProfileAnswers(
          guard,
          partial,
          trust: AuthProfileAnswerTrust.backendUnknown,
        );
      }
    } on SessionEpochInvalidated {
      rethrow;
    } catch (_) {
      // Hydration is best-effort — never block login flow
      if (kDebugMode) {
        debugPrint('[AuthProvider] Profile hydration failed');
      }
    }
  }

  Future<void> _writeProfileAnswers(
    SessionEpochGuard guard,
    Map<String, dynamic> partial, {
    required AuthProfileAnswerTrust trust,
  }) async {
    guard.assertCurrent();
    final writer = _profileAnswerWriter;
    if (writer != null) {
      await writer(Map<String, dynamic>.from(partial), trust, guard);
      guard.assertCurrent();
      return;
    }
    await _sessionEpoch.runGuardedPersistence(
      guard,
      () => ReportPersistenceService.mutateAnswers((current) {
        guard.assertCurrent();
        final effectivePartial = Map<String, dynamic>.from(partial);
        if (trust == AuthProfileAnswerTrust.backendUnknown &&
            effectivePartial.containsKey('q_birth_year') &&
            _hasAuthoritativeExactDateOfBirth(current)) {
          effectivePartial.remove('q_birth_year');
        }
        if (effectivePartial.isEmpty) return null;
        final next = Map<String, dynamic>.from(current)
          ..addAll(effectivePartial);
        _stampProfileAnswerProvenance(
          next,
          effectivePartial.keys,
          trust: trust,
        );
        return next;
      }),
    );
    guard.assertCurrent();
  }

  Future<void> _bindPendingIdentity(
    SessionEpochGuard guard, {
    required String email,
  }) async {
    final pending = await _sessionEpoch.runGuardedPersistence(
      guard,
      () => _pendingAuthIdentityStore.bind(email: email),
    );
    guard.assertCurrent();
    _pendingAuthIdentity = pending;
  }

  Future<void> _bindResolvedPendingIdentity(
    SessionEpochGuard guard, {
    required String email,
    required String userId,
  }) async {
    final current = _pendingAuthIdentity;
    if (current == null) return;
    if (!await _pendingAuthIdentityStore.matches(
      current,
      email: email,
      userId: userId,
    )) {
      throw StateError('Resolved authentication identity mismatch');
    }
    guard.assertCurrent();
    final pending = await _sessionEpoch.runGuardedPersistence(
      guard,
      () => _pendingAuthIdentityStore.bind(email: email, userId: userId),
    );
    guard.assertCurrent();
    _pendingAuthIdentity = pending;
  }

  Future<void> _releasePendingIdentityIfMigrated(
    SessionEpochGuard guard, {
    required String email,
    required String userId,
  }) async {
    if (_pendingAuthIdentity == null) return;
    final prefs = await SharedPreferences.getInstance();
    guard.assertCurrent();
    if (!(prefs.getBool('local_data_migrated_$userId') ?? false)) return;
    await _sessionEpoch.runGuardedPersistence(
      guard,
      () => _pendingAuthIdentityStore.clearMatching(
        email: email,
        userId: userId,
      ),
    );
    guard.assertCurrent();
    _pendingAuthIdentity = null;
  }

  static void _assertRequestedIdentity({
    required String requestedEmail,
    required String resolvedEmail,
  }) {
    if (requestedEmail.trim().toLowerCase() !=
        resolvedEmail.trim().toLowerCase()) {
      throw StateError('Resolved authentication email mismatch');
    }
  }

  static bool _hasAuthoritativeExactDateOfBirth(
    Map<String, dynamic> answers,
  ) {
    final raw = answers['q_date_of_birth'];
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return false;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || _formatCivilDate(parsed) != raw) return false;
    final rawProvenance = answers['__provenance'];
    if (rawProvenance is! Map) return false;
    final envelope = rawProvenance['dateOfBirth'];
    if (envelope is! Map) return false;
    final source = envelope['source'];
    return source == ProfileDataSource.userInput.name ||
        source == ProfileDataSource.certificate.name ||
        source == ProfileDataSource.crossValidated.name;
  }

  static const _authAnswerProvenancePaths = <String, String>{
    'q_firstname': 'firstName',
    'q_birth_year': 'birthYear',
    'q_date_of_birth': 'dateOfBirth',
    'q_canton': 'canton',
    'q_gender': 'gender',
    'q_gross_salary_annual': 'salaireBrutMensuel',
    'q_net_income_period_chf': 'monthlyNetIncomeDeclared',
  };

  static void _stampProfileAnswerProvenance(
    Map<String, dynamic> answers,
    Iterable<String> answerKeys, {
    required AuthProfileAnswerTrust trust,
  }) {
    final paths = answerKeys
        .map((key) => _authAnswerProvenancePaths[key])
        .whereType<String>()
        .toSet();
    if (paths.isEmpty) return;
    _removeOverwrittenLocalProvenance(answers, paths);
    final rawUnknown = answers[coachBackendUnknownPathsKey];
    final unknownPaths = rawUnknown is List
        ? rawUnknown.whereType<String>().toSet()
        : <String>{};
    if (trust == AuthProfileAnswerTrust.backendUnknown) {
      unknownPaths.addAll(paths);
    } else {
      unknownPaths.removeAll(paths);
    }
    if (unknownPaths.isEmpty) {
      answers.remove(coachBackendUnknownPathsKey);
    } else {
      answers[coachBackendUnknownPathsKey] = unknownPaths.toList()..sort();
    }
    if (trust == AuthProfileAnswerTrust.backendUnknown) return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final provenance = Map<String, dynamic>.from(
      answers['__provenance'] as Map? ?? const <String, dynamic>{},
    );
    final sources = Map<String, dynamic>.from(
      answers['_coach_data_sources'] as Map? ?? const <String, dynamic>{},
    );
    final timestamps = Map<String, dynamic>.from(
      answers['_coach_data_timestamps'] as Map? ?? const <String, dynamic>{},
    );
    final sourceDates = Map<String, dynamic>.from(
      answers['_coach_data_source_dates'] as Map? ?? const <String, dynamic>{},
    );
    for (final path in paths) {
      provenance[path] = <String, dynamic>{
        'source': ProfileDataSource.userInput.name,
        'updatedAt': timestamp,
        'sourceDate': null,
      };
      sources[path] = ProfileDataSource.userInput.name;
      timestamps[path] = timestamp;
      sourceDates[path] = null;
    }
    answers['__provenance'] = provenance;
    answers['_coach_data_sources'] = sources;
    answers['_coach_data_timestamps'] = timestamps;
    answers['_coach_data_source_dates'] = sourceDates;
  }

  static String _formatCivilDate(DateTime value) {
    String twoDigits(int component) => component.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${twoDigits(value.month)}-${twoDigits(value.day)}';
  }

  static void _removeOverwrittenLocalProvenance(
    Map<String, dynamic> answers,
    Set<String> overwrittenPaths,
  ) {
    for (final envelopeKey in const <String>{
      '__provenance',
      '_coach_data_sources',
      '_coach_data_timestamps',
      '_coach_data_source_dates',
    }) {
      final raw = answers[envelopeKey];
      if (raw is! Map) continue;
      final cleaned = Map<String, dynamic>.from(raw)
        ..removeWhere((path, _) => overwrittenPaths.contains(path));
      if (cleaned.isEmpty) {
        answers.remove(envelopeKey);
      } else {
        answers[envelopeKey] = cleaned;
      }
    }
  }

  Future<void> _scheduleFreshStartNotifications(
    SessionEpochGuard guard,
  ) {
    return _sessionEpoch.runGuardedPersistence(
      guard,
      () => FreshStartService().scheduleAllFreshStartNotifications(),
    );
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Enable anonymous local mode so the router's auth guard lets users
  /// browse tabs without creating an account. Persisted across launches.
  Future<void> enableLocalMode() async {
    if (_isSessionTerminationBlocked) {
      throw StateError('Session termination must complete before local mode');
    }
    final guard = _sessionEpoch.capture();
    final prefs = await SharedPreferences.getInstance();
    await _sessionEpoch.runGuardedPersistence(
      guard,
      () async {
        await prefs.setBool('auth_local_mode', true);
      },
    );
    guard.assertCurrent();
    _isLocalMode = true;
    if (!_disposed) notifyListeners();
  }

  bool _rejectSessionEntryWhileTerminating() {
    if (!_isSessionTerminationBlocked) return false;
    _isLoading = false;
    _error = AuthError.serviceUnavailable;
    if (!_disposed) notifyListeners();
    return true;
  }

  bool _rejectAuthenticatedSessionEntry() {
    if (!_isLoggedIn) return false;
    _isLoading = false;
    _error = AuthError.serviceUnavailable;
    if (!_disposed) notifyListeners();
    return true;
  }

  bool _isCurrent(SessionEpochGuard guard) {
    try {
      guard.assertCurrent();
      return true;
    } on SessionEpochInvalidated {
      return false;
    }
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

    // Backend error fragments are classifier inputs, not UI copy. Unicode
    // escapes preserve the exact runtime matching without bypassing UI lints.
    if (lower.contains('existe d\u00e9j\u00e0')) {
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
    if (lower.contains('non v\u00e9rifi\u00e9') ||
        lower.contains('not verified')) {
      return AuthError.emailNotVerified;
    }

    return AuthError.genericError;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _apiSessionTerminationBinding?.dispose();
    _apiSessionTerminationBinding = null;
    if (_ownsSessionTerminationCoordinator) {
      _sessionTerminationCoordinator.dispose();
    }
    super.dispose();
  }
}
