import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/biography/biography_repository.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/install_lifecycle_service.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';
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

enum MintAccountDataState {
  anonymousLocal,
  signedOut,
  accountSyncOff,
  cloudSyncOn,
  deletePending,
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

/// Translate an exception-like auth failure into localized UI copy.
///
/// Use this in UI `catch` blocks instead of displaying `error.toString()`.
String localizeAuthException(Object error, S l) {
  return localizeAuthError(_authErrorFromException(error), l);
}

AuthError _authErrorFromException(Object error) {
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
      lower.contains('recreate_required') ||
      lower.contains('service indisponible')) {
    return AuthError.registrationUnavailable;
  }

  if (lower.contains('apple identity') ||
      lower.contains('apple sign-in audience') ||
      lower.contains('apple sign-in verification failed')) {
    return AuthError.serviceUnavailable;
  }

  final platformText = error is PlatformException
      ? [
          error.code,
          error.message,
          error.details,
        ].whereType<Object>().join(' ').toLowerCase()
      : lower;
  final nativeAppleAuthorizationFailure =
      platformText.contains('authenticationservices.authorizationerror') ||
          platformText.contains('asauthorizationerror') ||
          platformText.contains('com.apple.authenticationservices');
  final nativeAppleCancellation = nativeAppleAuthorizationFailure &&
      (platformText.contains('error 1001') ||
          platformText.contains('canceled') ||
          platformText.contains('cancelled'));

  if (nativeAppleCancellation) {
    return AuthError.genericError;
  }

  if (lower.contains('signinwithappleauthorizationexception') ||
      lower.contains('authorizationerrorcode') ||
      // Native iOS/TestFlight failures may arrive as a PlatformException from
      // AuthenticationServices instead of the typed sign_in_with_apple error.
      nativeAppleAuthorizationFailure) {
    return AuthError.serviceUnavailable;
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
  bool _isDeletingAccount = false;
  AuthLifecycleState _authLifecycle = AuthLifecycleState.sessionRestoring();
  // Local-mode default-on: the router's "authenticated" scope passes when
  // `isLoggedIn || isLocalMode`. Starting true keeps tab navigation alive
  // even if `checkAuth()` throws before the prefs block runs (e.g. on a
  // keychain failure). `register()`/`login()` explicitly flip this to false.
  // Cloud sync defaults off; this legacy bool now means "cloud sync off" for
  // accounts, not "the user deliberately entered guest mode".
  bool _isLocalMode = true;
  static const _authLocalModeKey = 'auth_local_mode';
  static const _mintInstallIdKey = '_mint_install_id';

  static String _localDataSyncPendingKey(String userId) =>
      'local_data_sync_pending_$userId';

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  bool get isLoading => _isLoading;
  AuthError? get error => _error;
  bool get requiresEmailVerification => _requiresEmailVerification;
  AuthLifecycleState get authLifecycle => _authLifecycle;

  @visibleForTesting
  static Map<String, dynamic> mergeBackendProfileDataForTest(
    Map<String, dynamic> currentAnswers,
    Map<String, dynamic> profilePayload,
  ) {
    return _mergeBackendProfileData(currentAnswers, profilePayload);
  }

  static Map<String, dynamic> _mergeBackendProfileData(
    Map<String, dynamic> currentAnswers,
    Map<String, dynamic> profilePayload,
  ) {
    final nestedData = profilePayload['data'];
    final data = nestedData is Map
        ? Map<String, dynamic>.from(nestedData)
        : Map<String, dynamic>.from(profilePayload);
    if (data.isEmpty) return currentAnswers;
    final claimAnswers = _localDataClaimWizardAnswers(data);
    if (claimAnswers.isEmpty && _isBootstrapOnlyBackendProfileData(data)) {
      return currentAnswers;
    }

    final answers = Map<String, dynamic>.from(currentAnswers);
    for (final entry in claimAnswers.entries) {
      if (_isMissingAnswer(answers, entry.key)) {
        answers[entry.key] = entry.value;
      }
    }
    final claimHasSelfEmployedAnnual = claimAnswers.containsKey(
      'q_self_employed_net_income_annual_chf',
    );
    final claimHasPillar3aAnnual = claimAnswers.containsKey(
      'q_3a_annual_contribution',
    );
    bool fillIfMissing(String key, dynamic value) {
      if (value == null) return false;
      if (!_isMissingAnswer(answers, key)) return false;
      answers[key] = value;
      return true;
    }

    bool fillNumIfMissing(String key, dynamic value) {
      if (value is! num) return false;
      return fillIfMissing(key, value.toDouble());
    }

    double? numberAnswer(String key) {
      final value = answers[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    if (claimHasPillar3aAnnual &&
        !claimAnswers.containsKey('q_has_3a') &&
        _isMissingAnswer(answers, 'q_has_3a')) {
      final claim3aAnnual = numberAnswer('q_3a_annual_contribution');
      final known3aBalance = numberAnswer('q_3a_total') ?? 0;
      if (claim3aAnnual != null && claim3aAnnual > 0) {
        answers['q_has_3a'] = true;
      } else if (claim3aAnnual != null &&
          claim3aAnnual == 0 &&
          known3aBalance <= 0) {
        answers['q_has_3a'] = false;
      }
    }

    bool closeToAmount(double a, double b) => (a - b).abs() < 0.01;

    fillIfMissing('q_firstname', data['firstName']);
    if (data['dateOfBirth'] != null) {
      final rawDateOfBirth = data['dateOfBirth'] as String;
      fillIfMissing('q_date_of_birth', rawDateOfBirth);
      if (!_isAnswered(answers['q_birth_year'])) {
        final parsedDateOfBirth = DateTime.tryParse(rawDateOfBirth);
        if (parsedDateOfBirth != null) {
          answers['q_birth_year'] = parsedDateOfBirth.year;
        }
      }
    }
    if (data['birthYear'] != null) {
      fillIfMissing('q_birth_year', data['birthYear'] as int);
    }
    if (data['canton'] != null) {
      fillIfMissing('q_canton', data['canton'] as String);
    }
    if (data['commune'] != null) {
      fillIfMissing('q_commune', data['commune'] as String);
    }
    if (data['gender'] != null) {
      fillIfMissing('q_gender', data['gender'] as String);
    }
    if (data['nationality'] != null) {
      fillIfMissing('q_nationality', data['nationality'] as String);
    }
    if (data['usTaxPerson'] != null) {
      fillIfMissing('q_us_tax_person', data['usTaxPerson'] as bool);
    }
    if (data['residencePermit'] != null) {
      fillIfMissing('q_residence_permit', data['residencePermit'] as String);
    }
    if (data['employmentStatus'] != null) {
      fillIfMissing(
        'q_employment_status',
        CoachProfile.employmentStatusFromCanonical(
          data['employmentStatus'] as String,
        ),
      );
    }
    if (data['selfEmployedNetIncome'] is num && !claimHasSelfEmployedAnnual) {
      final annual = (data['selfEmployedNetIncome'] as num).toDouble();
      final previousAnnual = numberAnswer(
        'q_self_employed_net_income_annual_chf',
      );
      final previousMonthly = numberAnswer('q_net_income_period_chf');
      final previousMonthlySource = answers['q_net_income_period_source'];
      final previousEmployment = answers['q_employment_status'];
      final monthlyWasDerivedFromPreviousAnnual =
          previousMonthlySource == 'derived_self_employed_annual_proxy' &&
              previousAnnual != null &&
              previousMonthly != null &&
              closeToAmount(previousMonthly, previousAnnual / 12);
      final shouldUseIndependentStatus =
          _isMissingAnswer(answers, 'q_employment_status') ||
              _isIndependentEmployment(previousEmployment);

      answers['q_self_employed_net_income_annual_chf'] = annual;
      if (shouldUseIndependentStatus) {
        answers['q_employment_status'] = 'independant';
      }
      if (shouldUseIndependentStatus && annual.isFinite && annual > 0) {
        if (_isMissingAnswer(answers, 'q_net_income_period_chf') ||
            monthlyWasDerivedFromPreviousAnnual) {
          answers['q_net_income_period_chf'] = annual / 12;
          answers['q_pay_frequency'] = 'monthly';
          answers['q_net_income_period_source'] =
              'derived_self_employed_annual_proxy';
        }
      }
    }
    if (data['incomeGrossYearly'] != null) {
      fillNumIfMissing('q_gross_salary_annual', data['incomeGrossYearly']);
    }
    if (data['incomeNetMonthly'] != null) {
      final filledMonthlyIncome = fillNumIfMissing(
        'q_net_income_period_chf',
        data['incomeNetMonthly'],
      );
      if (filledMonthlyIncome) {
        answers['q_pay_frequency'] = 'monthly';
      }
    }
    if (data['householdType'] != null) {
      fillIfMissing('q_household_type', data['householdType'] as String);
    }
    if (data['has2ndPillar'] != null) {
      fillIfMissing('q_has_pension_fund', data['has2ndPillar'] as bool);
    }
    if (data['avoirLpp'] != null) {
      fillIfMissing('q_has_pension_fund', true);
    }
    fillNumIfMissing('_coach_avoir_lpp', data['avoirLpp']);
    fillNumIfMissing('_coach_salaire_assure', data['lppInsuredSalary']);
    fillNumIfMissing('_coach_rachat_maximum', data['lppBuybackMax']);
    if (data['hasVoluntaryLpp'] == true &&
        answers['q_employment_status'] == 'independant') {
      fillIfMissing('q_has_pension_fund', true);
    }
    fillNumIfMissing('q_3a_total', data['pillar3aBalance']);
    if (data['pillar3aAnnual'] is num) {
      final annual3a = (data['pillar3aAnnual'] as num).toDouble();
      final known3aBalance = numberAnswer('q_3a_total') ?? 0;
      if (!claimHasPillar3aAnnual) {
        answers['q_3a_annual_contribution'] = annual3a;
        if (annual3a > 0) {
          answers['q_has_3a'] = true;
        } else if (annual3a == 0 && known3aBalance <= 0) {
          answers['q_has_3a'] = false;
        }
      }
    }
    fillNumIfMissing('q_savings_monthly', data['savingsMonthly']);
    fillNumIfMissing('q_cash_total', data['totalSavings']);
    if (data['hasDebt'] == true) {
      fillIfMissing('q_has_consumer_debt', 'yes');
    }
    fillNumIfMissing('q_total_debt_balance_chf', data['totalDebt']);
    if (data['avsContributionYears'] is num) {
      fillIfMissing(
        'q_avs_contribution_years',
        (data['avsContributionYears'] as num).toInt(),
      );
    }
    if (data['targetRetirementAge'] is num) {
      fillIfMissing(
        'q_target_retirement_age',
        (data['targetRetirementAge'] as num).toInt(),
      );
    }
    if (data['spouseBirthYear'] is num) {
      fillIfMissing(
        'q_partner_birth_year',
        (data['spouseBirthYear'] as num).toInt(),
      );
    }
    fillNumIfMissing(
      'q_partner_net_income_chf',
      data['spouseIncomeNetMonthly'],
    );
    if (data['spouseAvsContributionYears'] is num) {
      fillIfMissing(
        'q_spouse_avs_contribution_years',
        (data['spouseAvsContributionYears'] as num).toInt(),
      );
    }
    return answers;
  }

  static bool _isMissingAnswer(Map<String, dynamic> answers, String key) {
    if (!answers.containsKey(key)) return true;
    final value = answers[key];
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  static bool _isIndependentEmployment(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'independant' ||
        normalized == 'indépendant' ||
        normalized == 'independent' ||
        normalized == 'self_employed';
  }

  static Map<String, dynamic> _localDataClaimWizardAnswers(
    Map<String, dynamic> data,
  ) {
    final claim = data['localDataClaim'];
    if (claim is! Map) return const {};
    final rawWizardAnswers = claim['wizardAnswers'];
    if (rawWizardAnswers is! Map) return const {};
    return Map<String, dynamic>.from(rawWizardAnswers);
  }

  static bool _isBootstrapOnlyBackendProfileData(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      final value = entry.value;
      if (value == null) continue;
      switch (entry.key) {
        case 'id':
        case 'createdAt':
        case 'updatedAt':
          continue;
        case 'householdType':
          if (value == 'single') continue;
          return false;
        case 'hasDebt':
        case 'isChurchMember':
          if (value == false) continue;
          return false;
        case 'goal':
          if (value == 'other') continue;
          return false;
        case 'factfindCompletionIndex':
          if (value is num && value == 0) continue;
          return false;
        case 'voiceCursorPreference':
          if (value == 'direct') continue;
          return false;
        case 'n5IssuedThisWeek':
          if (value is num && value == 0) continue;
          return false;
        case 'recentGravityEvents':
          if (value is List && value.isEmpty) continue;
          return false;
        case 'localDataClaim':
          final claim = value;
          if (claim is Map) {
            final wizardAnswers = claim['wizardAnswers'];
            if (wizardAnswers is! Map || wizardAnswers.isEmpty) continue;
          }
          return false;
        default:
          return false;
      }
    }
    return true;
  }

  static bool _isAnswered(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num) return value != 0;
    return true;
  }

  bool get isLocalMode => _isLocalMode;

  /// Phase 52: cloud-sync state from the user's perspective.
  /// `true` ⇔ user has explicitly opted into multi-device sync; data
  /// is mirrored to the backend on each save. `false` (default after
  /// register) ⇔ data stays on device.
  bool get isCloudSyncEnabled => !_isLocalMode;

  MintAccountDataState get accountDataState {
    if (_isDeletingAccount) return MintAccountDataState.deletePending;
    if (!_isLoggedIn) {
      return _isLocalMode
          ? MintAccountDataState.anonymousLocal
          : MintAccountDataState.signedOut;
    }
    return _isLocalMode
        ? MintAccountDataState.accountSyncOff
        : MintAccountDataState.cloudSyncOn;
  }

  /// Check stored auth on app startup
  Future<void> checkAuth() async {
    _isLoading = true;
    _authLifecycle = AuthLifecycleState.sessionRestoring();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasExplicitLocalMode = prefs.containsKey(_authLocalModeKey);
      _isLocalMode = prefs.getBool(_authLocalModeKey) ?? true;
      final mayRestoreAuth =
          await InstallLifecycleService.prepareForAuthRestore();
      final isLoggedIn =
          mayRestoreAuth ? await AuthService.isLoggedIn() : false;
      if (isLoggedIn) {
        _userId = await AuthService.getUserId();
        _email = await AuthService.getUserEmail();
        _displayName = await AuthService.getDisplayName();
        if (_userId == null || _userId!.isEmpty) {
          await AuthService.logout();
          _isLoggedIn = false;
          _userId = null;
          _email = null;
          _displayName = null;
          _authLifecycle = AuthLifecycleState.sessionExpired();
          ConversationStore.setCurrentUserId(null);
          _error = null;
          return;
        }
        _isLoggedIn = true;
        _authLifecycle = AuthLifecycleState.signedInProfileLoading(
          userId: _userId!,
          cloudSyncEnabled: isCloudSyncEnabled,
        );
        // FIX-W11-7: Set user prefix for conversation isolation.
        ConversationStore.setCurrentUserId(_userId);
        _error = null;
        // Full restored-session contract: hydrate profile and schedule
        // fresh-start notifications. Do not claim anonymous conversations on
        // silent restore; a signed account must not inherit guest chat state
        // by accident.
        await _migrateLocalDataIfNeeded();
        final hasProfile = await _hydrateProfileFromBackend();
        _authLifecycle = _settledAccountLifecycle(hasProfile: hasProfile);
        try {
          await FreshStartService().scheduleAllFreshStartNotifications();
        } catch (e) {
          debugPrint('[Auth] best-effort failed: $e');
        }
      } else {
        _authLifecycle = _isLocalMode && hasExplicitLocalMode
            ? AuthLifecycleState.guestEmpty(
                installId: await _loadOrCreateInstallId(prefs),
              )
            : AuthLifecycleState.freshVisitor();
      }
      // F3-2: Restore email verification state from SharedPreferences.
      // Survives cold start so the verify-email screen is shown again.
      _requiresEmailVerification =
          prefs.getBool('requires_email_verification') ?? false;
      // Missing `auth_local_mode` means no explicit guest choice yet. For
      // accounts, the legacy value still means cloud sync is opt-in/off by
      // default; for signed-out users it must not unlock main navigation.
    } catch (e) {
      _error = _toUserFriendlyAuthError(e);
      _isLoggedIn = false;
      _authLifecycle = AuthLifecycleState.sessionExpired();
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
        _authLifecycle = AuthLifecycleState.signedInProfileLoading(
          userId: userId,
          cloudSyncEnabled: isCloudSyncEnabled,
        );
        // Phase 52 (D-01): no longer auto-disable local mode on register.
        // Cloud sync is opt-in via Settings › Confidentialité.
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
        await _migrateLocalDataIfNeeded(claimAnonymousConversations: true);
        final hasProfile = await _hydrateProfileFromBackend();
        _authLifecycle = _settledAccountLifecycle(hasProfile: hasProfile);
        // Best-effort: schedule fresh-start notifications
        try {
          await FreshStartService().scheduleAllFreshStartNotifications();
        } catch (e) {
          debugPrint('[Auth] best-effort failed: $e');
        }
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
      _authLifecycle = AuthLifecycleState.signedInProfileLoading(
        userId: userId,
        cloudSyncEnabled: isCloudSyncEnabled,
      );
      // Phase 52 (D-01): no longer auto-disable local mode on login.
      // Cloud sync is opt-in via Settings › Confidentialité.
      // FIX-W11-7: Set user prefix for conversation isolation.
      ConversationStore.setCurrentUserId(userId);
      _requiresEmailVerification = false;
      _error = null;
      _isLoading = false;

      await _migrateLocalDataIfNeeded();
      // FIX-W11-5: Hydrate local state from backend on new device login
      final hasProfile = await _hydrateProfileFromBackend();
      _authLifecycle = _settledAccountLifecycle(hasProfile: hasProfile);
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
  ///   4. Optionally claiming local anonymous conversations
  ///   5. Hydrating profile from backend
  ///   6. Scheduling fresh-start notifications
  ///
  /// The response must contain `accessToken`. `userId` and `email` are
  /// optional (backend may omit them on Apple's hidden email flow).
  ///
  /// Returns `true` on success, `false` on failure (error is set).
  Future<bool> completeAppleSignIn(
    Map<String, dynamic> response, {
    required bool claimAnonymousConversations,
  }) async {
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
      _authLifecycle = AuthLifecycleState.signedInProfileLoading(
        userId: userId,
        cloudSyncEnabled: isCloudSyncEnabled,
      );
      // Phase 52 (D-01): no longer auto-disable local mode on Apple SSO.
      // Cloud sync is opt-in via Settings › Confidentialité.
      _requiresEmailVerification = false;
      _error = null;
      // FIX-W11-7: Set user prefix for conversation isolation.
      ConversationStore.setCurrentUserId(_userId);

      await _migrateLocalDataIfNeeded(
        claimAnonymousConversations: claimAnonymousConversations,
      );
      final hasProfile = await _hydrateProfileFromBackend();
      _authLifecycle = _settledAccountLifecycle(hasProfile: hasProfile);
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
    if (FeatureFlags.enableMvpWedgeOnboarding &&
        await AccountHandoffService.requiresExplicitChoice(
          handoffEnabled: true,
        )) {
      _error = AuthError.invalidInput;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.verifyMagicLink(token);

      // Backend returns camelCase: { accessToken, tokenType }
      final accessToken =
          (response['accessToken'] ?? response['access_token']) as String;

      try {
        final userInfo = await ApiService.getMeWithToken(accessToken);
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
        throw const FormatException('Magic link user info unavailable');
      }

      _isLoggedIn = true;
      if (_userId != null && _userId!.isNotEmpty) {
        _authLifecycle = AuthLifecycleState.signedInProfileLoading(
          userId: _userId!,
          cloudSyncEnabled: isCloudSyncEnabled,
        );
      }
      // Phase 52 (D-01): no longer auto-disable local mode on magic link.
      // Cloud sync is opt-in via Settings › Confidentialité.
      _requiresEmailVerification = false;
      _error = null;
      _isLoading = false;

      if (_userId != null) {
        ConversationStore.setCurrentUserId(_userId);
        await _migrateLocalDataIfNeeded();
        final hasProfile = await _hydrateProfileFromBackend();
        _authLifecycle = _settledAccountLifecycle(hasProfile: hasProfile);
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
    _isDeletingAccount = true;
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
      _isLocalMode = false;
      _authLifecycle = const AuthLifecycleState(
        state: AuthLifecycleKind.deletedSignedOut,
        accessMode: AuthAccessMode.visitor,
        activeDataScope: AuthDataScope.none,
        syncMode: AuthSyncMode.none,
      );
      await (await SharedPreferences.getInstance()).setBool(
        _authLocalModeKey,
        false,
      );
      _isDeletingAccount = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _toUserFriendlyAuthError(e);
      _isDeletingAccount = false;
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
    final accessToken = await AuthService.getToken();
    final refreshToken = await AuthService.getRefreshToken();
    unawaited(
      ApiService.logout(accessToken: accessToken, refreshToken: refreshToken),
    );
    await AuthService.logout();
    // FIX-W11-7: Clear user prefix on logout.
    ConversationStore.setCurrentUserId(null);
    await _purgeLocalData();
    _isLoggedIn = false;
    _userId = null;
    _email = null;
    _displayName = null;
    _requiresEmailVerification = false;
    _isLocalMode = false;
    _authLifecycle = AuthLifecycleState.freshVisitor();
    // Persist AFTER _purgeLocalData (which prefs.clear()s the store).
    // Logout = fully out; the user can re-enable local mode by tapping
    // "Continuer en mode local" on the register/login screens.
    await (await SharedPreferences.getInstance()).setBool(
      _authLocalModeKey,
      false,
    );
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
      await ReportPersistenceService.clearDiagnostic();
      final ownedSecurePurged =
          await InstallLifecycleService.purgeMintSecureStorage(
        includeAuthSession: false,
      );
      await InstallLifecycleService.recordOwnedSecurePurgeResult(
        ownedSecurePurged,
        prefs: prefs,
      );
      await _bestEffortPurge('BYOK key', () => ByokProvider.clearStoredKey());
      await _bestEffortPurge(
        'partner estimate',
        () => PartnerEstimateService.clear(),
      );
      await _bestEffortPurge(
        'anonymous session',
        () => AnonymousSessionService.clearSession(),
      );
      await _bestEffortPurge(
        'biography key',
        () => BiographyRepository.clearEncryptionKey(),
      );
    } catch (e) {
      // Purge is best-effort — never block auth flow
      if (kDebugMode) {
        debugPrint('[AuthProvider] Local data purge failed: $e');
      }
    }
  }

  Future<void> _bestEffortPurge(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthProvider] Local $label purge failed: $e');
      }
    }
  }

  /// Migrate eligible local data to the authenticated account.
  ///
  /// Called after successful auth to associate eligible pre-auth data
  /// (wizard answers, preferences, etc.) with the account for future cloud
  /// sync. Anonymous conversations are claimed only when explicitly requested
  /// by a creation/claim path.
  ///
  /// Safety: captures userId at call-time to avoid race conditions
  /// if the user logs out/in rapidly. Refuses to overwrite ownership
  /// if local data already belongs to a different account.
  Future<void> _migrateLocalDataIfNeeded({
    bool claimAnonymousConversations = false,
  }) async {
    final currentUserId = _userId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSyncKey = _localDataSyncPendingKey(currentUserId);
      final syncPending = prefs.getBool(pendingSyncKey) ?? false;
      bool shouldMigrate;
      if (syncPending) {
        shouldMigrate = true;
      } else if (FeatureFlags.enableMvpWedgeOnboarding) {
        shouldMigrate = await AccountHandoffService.prepareLocalDataForAccount(
          currentUserId,
          handoffEnabled: true,
        );
      } else {
        await AccountHandoffService.clearChoice();
        shouldMigrate = await AccountHandoffService.hasLocalData();
      }
      if (!shouldMigrate && !claimAnonymousConversations) return;

      final alreadyMigrated =
          prefs.getBool('local_data_migrated_$currentUserId') ?? false;
      if (alreadyMigrated && !syncPending && !claimAnonymousConversations) {
        return;
      }

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

      // Claim anonymous conversations only for explicit creation/claim flows.
      // Restored sessions and existing-account logins keep guest conversations
      // in the anonymous namespace so account chat never reuses them by accident.
      if (claimAnonymousConversations) {
        try {
          await ConversationStore.migrateAnonymousToUser(currentUserId);
          await AnonymousSessionService.clearSession();
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '[AuthProvider] Anonymous conversation migration failed: $e',
            );
          }
        }
      }

      await prefs.setString('local_data_owner', currentUserId);
      await prefs.setBool('local_data_migrated_$currentUserId', true);

      // Phase 52.1 B-2: gate the wizard-data backend push on the
      // cloud-sync toggle. New accounts default OFF (Phase 52 D-01)
      // → wizard answers stay on device. If the user later flips
      // sync ON in Settings › Confidentialité, the next save
      // naturally pushes via _syncToBackend (also gated by B-1).
      // Conversation claiming above is local→local within the device's
      // ConversationStore namespace and is unaffected.
      final cloudSyncEnabled = !(prefs.getBool('auth_local_mode') ?? true);
      if (cloudSyncEnabled) {
        // Push local wizard data to backend via claimLocalData.
        // Best-effort: failure does not block auth, but keeps a retry flag.
        try {
          final answers = await ReportPersistenceService.loadAnswers();
          final mint2AxisHandoff =
              await ReportPersistenceService.loadMint2AxisHandoff();
          if (answers.isNotEmpty || mint2AxisHandoff.isNotEmpty) {
            var deviceId = prefs.getString('_mint_device_id');
            if (deviceId == null) {
              deviceId = const Uuid().v4();
              await prefs.setString('_mint_device_id', deviceId);
            }
            await ApiService.claimLocalData(
              localDataVersion: 1,
              deviceId: deviceId,
              wizardAnswers: answers,
              mint2AxisHandoff: mint2AxisHandoff,
            );
          }
          await prefs.remove(pendingSyncKey);
        } catch (e) {
          await prefs.setBool(pendingSyncKey, true);
          if (kDebugMode) {
            debugPrint('[AuthProvider] claimLocalData sync failed: $e');
          }
        }
      } else if (syncPending) {
        await prefs.remove(pendingSyncKey);
      }
    } catch (e) {
      // Migration is best-effort — never block auth flow
      if (kDebugMode) {
        debugPrint('[AuthProvider] Local data migration failed: $e');
      }
    }
  }

  /// FIX-W11-5: Hydrate key profile fields from backend on login.
  ///
  /// On a new device the local SharedPreferences are empty. This fetches
  /// the cloud profile and seeds the most critical fields so screens
  /// don't show an empty state.
  AuthLifecycleState _settledAccountLifecycle({required bool hasProfile}) {
    final currentUserId = _userId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return AuthLifecycleState.sessionExpired();
    }
    if (!hasProfile) {
      return AuthLifecycleState.signedInProfileMissing(
        userId: currentUserId,
        cloudSyncEnabled: isCloudSyncEnabled,
      );
    }
    return isCloudSyncEnabled
        ? AuthLifecycleState.cloudSyncOnAccount(userId: currentUserId)
        : AuthLifecycleState.syncOffAccount(userId: currentUserId);
  }

  Future<bool> _hydrateProfileFromBackend() async {
    var existingAnswers = <String, dynamic>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _userId;
      final accountOwnsLocalAnswers = currentUserId != null &&
          prefs.getString('local_data_owner') == currentUserId &&
          (prefs.getBool('local_data_migrated_$currentUserId') ?? false);
      existingAnswers = await ReportPersistenceService.loadAnswers();
      if (!accountOwnsLocalAnswers && existingAnswers.isNotEmpty) {
        await ReportPersistenceService.holdActiveDiagnosticForAnonymous();
        existingAnswers = const {};
      }

      final profileData = await ApiService.get('/profiles/me');
      final answers =
          accountOwnsLocalAnswers ? existingAnswers : <String, dynamic>{};
      final merged = _mergeBackendProfileData(answers, profileData);

      if (!accountOwnsLocalAnswers && profileData.isEmpty) {
        return false;
      }

      if (merged.isNotEmpty && !mapEquals(merged, existingAnswers)) {
        await ReportPersistenceService.saveAnswers(merged);
      }
      return merged.isNotEmpty;
    } catch (e) {
      // Hydration is best-effort — never block login flow
      if (kDebugMode) {
        debugPrint('[AuthProvider] Profile hydration failed: $e');
      }
      return existingAnswers.isNotEmpty;
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Called after local onboarding successfully creates a CoachProfile for an
  /// already-authenticated account. Register/login can only inspect backend
  /// profile hydration at auth time; this bridges the later local profile seal.
  void markAccountProfileAvailable() {
    if (!_isLoggedIn || _userId == null || _userId!.isEmpty) return;
    _authLifecycle = _settledAccountLifecycle(hasProfile: true);
    notifyListeners();
  }

  /// Enable anonymous local mode so the router's auth guard lets users
  /// browse tabs without creating an account. Persisted across launches.
  Future<void> enableLocalMode() async {
    if (_isLoggedIn && _userId != null && _userId!.isNotEmpty) return;
    _isLocalMode = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authLocalModeKey, true);
    _authLifecycle = AuthLifecycleState.guestEmpty(
      installId: await _loadOrCreateInstallId(prefs),
    );
    notifyListeners();
  }

  /// Phase 52 (D-01, D-03): user-controlled cloud-sync toggle from
  /// Settings › Confidentialité. `true` enables multi-device sync
  /// (next save pushes to the backend), `false` keeps data on device.
  /// Persisted across launches via `auth_local_mode`.
  Future<void> toggleCloudSync(bool enabled) async {
    _isLocalMode = !enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authLocalModeKey, _isLocalMode);
    if (_isLoggedIn && _userId != null) {
      _authLifecycle =
          _authLifecycle.state == AuthLifecycleKind.signedInProfileMissing
              ? AuthLifecycleState.signedInProfileMissing(
                  userId: _userId!,
                  cloudSyncEnabled: enabled,
                )
              : _settledAccountLifecycle(
                  hasProfile: _authLifecycle.allowsMainNavigation,
                );
    }
    notifyListeners();
  }

  Future<String> _loadOrCreateInstallId(SharedPreferences prefs) async {
    final existing = prefs.getString(_mintInstallIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await prefs.setString(_mintInstallIdKey, generated);
    return generated;
  }

  AuthError _toUserFriendlyAuthError(Object error) {
    return _authErrorFromException(error);
  }
}
