import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// P2-18: Error codes for i18n — UI layer maps these to AppLocalizations.
enum ApiErrorCode {
  offline,
  timeout,
  authenticationRequired,
  sessionExpired,
  serverError,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isOffline;

  /// P2-18: Typed error code so the UI layer can map to i18n strings.
  final ApiErrorCode errorCode;

  const ApiException(
    this.message, {
    this.statusCode,
    this.isOffline = false,
    this.errorCode = ApiErrorCode.unknown,
  });

  /// FIX-071: User-friendly offline detection.
  static ApiException offline() => const ApiException(
        'Network offline',
        isOffline: true,
        errorCode: ApiErrorCode.offline,
      );

  static const ApiException timeout = ApiException(
    'Request timeout',
    errorCode: ApiErrorCode.timeout,
  );

  static ApiException sessionExpired() => const ApiException(
        'Session expired',
        statusCode: 401,
        errorCode: ApiErrorCode.sessionExpired,
      );

  static ApiException authenticationRequired() => const ApiException(
        'Authentication required',
        statusCode: 401,
        errorCode: ApiErrorCode.authenticationRequired,
      );

  /// P2-18: Resolve a user-facing message from AppLocalizations.
  /// Call this in UI layers that have BuildContext.
  String localizedMessage(dynamic l10n) {
    // l10n is AppLocalizations — dynamic to avoid import cycle.
    // UI consumers: `e.localizedMessage(AppLocalizations.of(context)!)`
    return switch (errorCode) {
      ApiErrorCode.offline => l10n.apiErrorOffline as String,
      ApiErrorCode.timeout => l10n.apiErrorTimeout as String,
      ApiErrorCode.authenticationRequired =>
        l10n.apiErrorSessionExpired as String,
      ApiErrorCode.sessionExpired => l10n.apiErrorSessionExpired as String,
      ApiErrorCode.serverError => l10n.apiErrorServer as String,
      ApiErrorCode.unknown => message,
    };
  }

  @override
  String toString() => message;
}

enum _RefreshResult { refreshed, unavailable, terminalFailure }

/// Lifetime token for the app-level terminal-session callback.
class ApiSessionTerminationBinding {
  ApiSessionTerminationBinding._(this._generation);

  final int _generation;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ApiService._unbindSessionTerminationHandler(_generation);
  }
}

final class _ApiAuthenticatedTransport implements AuthenticatedTransport {
  const _ApiAuthenticatedTransport();

  @override
  AuthenticatedOperation beginOperation() =>
      ApiService._beginAuthenticatedOperation();
}

final class _ApiAuthenticatedOperation implements AuthenticatedOperation {
  _ApiAuthenticatedOperation(this.guard);

  final SessionEpochGuard guard;
  String? boundUserId;
  String? boundEmail;

  @override
  Future<void> requireSession() => ApiService._requireSession(this);

  @override
  Future<AuthenticatedResponse> send(AuthenticatedRequest request) =>
      ApiService._authenticatedRequest(request, this);
}

// DECISION(2026-03-30): TLS certificate pinning DEFERRED for V1.
// Rationale: Railway uses Let's Encrypt with 90-day auto-renewal.
// Pinning would require rotating pins every 90 days — high risk of
// bricking the app if a pin rotation is missed. Railway handles TLS
// termination with HSTS (verified: Strict-Transport-Security header active).
// Revisit when: custom domain with controlled certificate lifecycle.
// Risk accepted: MITM via compromised CA (low probability, standard for fintech V1).
class ApiService {
  static http.Client _httpClient = http.Client();
  static Future<AuthSessionEnvelope?> Function() _authSessionReader =
      AuthService.readSessionEnvelope;
  static Future<void> Function()? _sessionTerminationHandler;
  static SessionEpoch? _sessionEpoch;
  static int _sessionTerminationGeneration = 0;
  static Future<void>? _inFlightSessionTermination;

  /// The single production implementation injected into authenticated
  /// consumers. Credential reads, refresh, epoch checks and terminal 401
  /// handling remain encapsulated in this file.
  static const AuthenticatedTransport authenticatedTransport =
      _ApiAuthenticatedTransport();

  /// Installs the only terminal 401 callback. MintApp owns the returned
  /// binding and disposes it with its AuthProvider.
  static ApiSessionTerminationBinding bindSessionTerminationHandler(
    Future<void> Function() handler, {
    SessionEpoch? sessionEpoch,
  }) {
    final generation = ++_sessionTerminationGeneration;
    _sessionTerminationHandler = handler;
    _sessionEpoch = sessionEpoch;
    return ApiSessionTerminationBinding._(generation);
  }

  static void _unbindSessionTerminationHandler(int generation) {
    if (generation != _sessionTerminationGeneration) return;
    _sessionTerminationHandler = null;
    _sessionEpoch = null;
  }

  static Future<void> _terminateExpiredSession() async {
    final existing = _inFlightSessionTermination;
    if (existing != null) return existing;
    final handler = _sessionTerminationHandler;
    if (handler == null) {
      throw StateError('Terminal session handler is not bound');
    }
    late final Future<void> operation;
    operation = handler().whenComplete(() {
      if (identical(_inFlightSessionTermination, operation)) {
        _inFlightSessionTermination = null;
      }
    });
    _inFlightSessionTermination = operation;
    await operation;
  }

  static _ApiAuthenticatedOperation _beginAuthenticatedOperation() {
    final epoch = _sessionEpoch;
    if (epoch == null) {
      throw StateError('Session epoch is not bound');
    }
    return _ApiAuthenticatedOperation(epoch.capture());
  }

  @visibleForTesting
  static void debugUseHttpClient(http.Client client) {
    _httpClient.close();
    _httpClient = client;
  }

  @visibleForTesting
  static void debugResetHttpClient() {
    _httpClient.close();
    _httpClient = http.Client();
  }

  @visibleForTesting
  static void debugResetSessionTerminationHandler() {
    _sessionTerminationGeneration++;
    _sessionTerminationHandler = null;
    _sessionEpoch = null;
    _inFlightSessionTermination = null;
  }

  @visibleForTesting
  static void debugUseAuthSessionReader(
    Future<AuthSessionEnvelope?> Function() reader,
  ) {
    _authSessionReader = reader;
  }

  @visibleForTesting
  static void debugResetAuthSessionReader() {
    _authSessionReader = AuthService.readSessionEnvelope;
  }

  /// CHAOS-4: Safe JSON decode — Railway can return HTML error pages
  /// that crash jsonDecode. Wraps in try-catch with ApiException.
  static dynamic _safeJsonDecode(String body, {int? statusCode}) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ApiException(
        'Invalid server response',
        statusCode: statusCode,
        errorCode: ApiErrorCode.serverError,
      );
    }
  }

  static const String _definedApiBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// Base URL candidates ordered by priority.
  /// Override with:
  ///   flutter run --dart-define=API_BASE_URL=https://<your-api>/api/v1
  static final List<String> _baseUrlCandidates = (() {
    final candidates = <String>[
      if (_definedApiBaseUrl.isNotEmpty) _definedApiBaseUrl,
      // Production first — release builds should default to production.
      if (kReleaseMode) 'https://mint-production-3a41.up.railway.app/api/v1',
      if (kReleaseMode) 'https://mint-staging.up.railway.app/api/v1',
      if (kReleaseMode) 'https://mint-api.up.railway.app/api/v1',
      if (!kReleaseMode) 'http://localhost:8888/api/v1',
    ];
    final normalized = <String>[];
    for (final raw in candidates) {
      final value = _normalizeBaseUrl(raw);
      if (!normalized.contains(value)) normalized.add(value);
    }
    return normalized;
  })();

  static String _activeBaseUrl = _baseUrlCandidates.first;

  static String get baseUrl => _activeBaseUrl;

  static String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.endsWith('/api/v1')) {
      value = '$value/api/v1';
    }
    return value;
  }

  static bool _isUnavailableEndpoint(http.Response response) {
    if (response.statusCode != 404) return false;
    final body = response.body.toLowerCase();
    return body.contains('application not found') ||
        body.contains('<html') ||
        body.contains('not found');
  }

  /// Probe known backend URLs and keep the first reachable one.
  /// Prevents release builds from getting stuck on a dead domain.
  static Future<void> ensureReachableBaseUrl() async {
    // In tests/dev without explicit API_BASE_URL, avoid network probing.
    if (!kReleaseMode && _definedApiBaseUrl.isEmpty) {
      return;
    }

    for (final candidate in _baseUrlCandidates) {
      try {
        final response = await http
            .get(Uri.parse('$candidate/health'))
            .timeout(const Duration(seconds: 2));
        if (_isUnavailableEndpoint(response)) {
          continue;
        }
        if (response.statusCode >= 200 && response.statusCode < 500) {
          _activeBaseUrl = candidate;
          return;
        }
      } catch (_) {
        // Try next candidate.
      }
    }
  }

  /// App version sent with every request for backend compatibility checks.
  static const String _appVersion = '1.0.0';

  // Helper method to get auth headers with JWT token + version
  static Future<Map<String, String>> _authHeaders() async {
    final token = (await _authSessionReader())?.accessToken;
    return _authHeadersForAccessToken(token);
  }

  static Map<String, String> _authHeadersForAccessToken(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'X-App-Version': _appVersion,
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    // OBS-04 (Phase 31-01) — D-05 dual-header trace propagation:
    // `sentry-trace` (Sentry OTLP-compatible) + `baggage` (W3C).
    // Legacy `X-MINT-Trace-Id` continues via backend LoggingMiddleware —
    // this is ADDITIVE, not a replacement. Reuses any active span set
    // by the caller; otherwise creates a short-lived http.client span.
    _injectSentryTraceHeaders(headers);
    return headers;
  }

  /// Headers for UNAUTHENTICATED endpoints (/auth/login, /auth/register,
  /// /auth/magic-link/*, /auth/password-reset/*, /auth/email-verification/*,
  /// /auth/apple/verify, /auth/refresh, /sessions).
  ///
  /// OBS-04 coverage gap mitigation (revision-critical): even non-auth
  /// calls MUST propagate sentry-trace + baggage for end-to-end
  /// observability of registration / login / magic-link failures — the
  /// most observability-critical error paths. OBS-04 REQ spec is "ALL
  /// HTTP calls carry sentry-trace", not "authenticated ones only".
  ///
  /// Does NOT include `Authorization` header (caller is unauthenticated
  /// by design). Post-migration invariant enforced by plan verify clause:
  /// only two definitions of the Content-Type literal remain in this
  /// file (one in _authHeaders, one in _publicHeaders — no bypasses
  /// left). See 31-01-SUMMARY.md for grep contract.
  static Map<String, String> _publicHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'X-App-Version': _appVersion,
    };
    _injectSentryTraceHeaders(headers);
    return headers;
  }

  /// Inject D-05 propagation headers into the supplied map. Shared by
  /// `_authHeaders()` and `_publicHeaders()` so both codepaths keep the
  /// exact same propagation semantics.
  static void _injectSentryTraceHeaders(Map<String, String> headers) {
    final span = Sentry.getSpan() ??
        Sentry.startTransaction('api.request', 'http.client');
    final sentryTrace = span.toSentryTrace();
    headers['sentry-trace'] = sentryTrace.value;
    final baggage = span.toBaggageHeader();
    if (baggage != null) {
      headers['baggage'] = baggage.value;
    }
  }

  /// Test-only accessor — `test/services/api_service_sentry_trace_test.dart`
  /// asserts `sentry-trace` header presence (OBS-04 a). Do NOT use in
  /// production code.
  @visibleForTesting
  static Future<Map<String, String>> debugAuthHeaders() => _authHeaders();

  /// Test-only accessor — same role as [debugAuthHeaders] but for the
  /// unauthenticated code path.
  @visibleForTesting
  static Map<String, String> debugPublicHeaders() => _publicHeaders();

  /// F5: Proactively refresh the auth token on app resume.
  /// Silently no-ops if no refresh token or if user is not logged in.
  static Future<void> refreshTokenIfNeeded() async {
    final operation = _beginAuthenticatedOperation();
    try {
      await operation.requireSession();
    } on ApiException catch (error) {
      if (error.errorCode == ApiErrorCode.authenticationRequired) return;
      rethrow;
    }
    final result = await _tryRefreshToken(operation);
    operation.guard.assertCurrent();
    if (result == _RefreshResult.terminalFailure) {
      await _terminateExpiredSession();
    }
  }

  /// Attempt to refresh tokens using the stored refresh token.
  /// Distinguishes an unavailable refresh credential from terminal failure.
  static Future<_RefreshResult> _tryRefreshToken(
    _ApiAuthenticatedOperation operation,
  ) =>
      _performRefresh(operation);

  static Future<_RefreshResult> _performRefresh(
    _ApiAuthenticatedOperation operation,
  ) async {
    final epoch = _sessionEpoch;
    if (epoch == null) {
      throw StateError('Session epoch is not bound');
    }
    operation.guard.assertCurrent();
    final authority = await _readOperationAuthority(operation);
    final refreshToken = authority.refreshToken;
    if (refreshToken == null) return _RefreshResult.unavailable;

    try {
      // The credential read above may suspend on Keychain. Reassert the epoch
      // after that read and immediately before the network boundary.
      operation.guard.assertCurrent();
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: _publicHeaders(),
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        operation.guard.assertCurrent();
        final decoded =
            _safeJsonDecode(response.body, statusCode: response.statusCode);
        if (decoded is! Map) {
          throw ApiException(
            'Invalid refresh response',
            statusCode: response.statusCode,
            errorCode: ApiErrorCode.serverError,
          );
        }
        final data = Map<String, dynamic>.from(decoded);
        final token = data['access_token'];
        final userId = data['user_id'];
        final email = data['email'];
        if (token is! String ||
            token.trim().isEmpty ||
            userId is! String ||
            userId.trim().isEmpty ||
            email is! String ||
            email.trim().isEmpty) {
          return _RefreshResult.terminalFailure;
        }
        if (userId != authority.userId || email != authority.email) {
          return _RefreshResult.terminalFailure;
        }
        final rotatedRefresh = data['refresh_token'];
        if (rotatedRefresh != null &&
            (rotatedRefresh is! String || rotatedRefresh.trim().isEmpty)) {
          return _RefreshResult.terminalFailure;
        }
        Future<void> save() => AuthService.saveToken(
              token,
              authority.userId,
              authority.email,
              displayName: authority.displayName,
              refreshToken: rotatedRefresh as String? ?? refreshToken,
            );
        await epoch.runGuardedPersistence(operation.guard, save);
        operation.guard.assertCurrent();
        return _RefreshResult.refreshed;
      }
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        return _RefreshResult.terminalFailure;
      }
      throw ApiException(
        'Refresh service unavailable',
        statusCode: response.statusCode,
        errorCode: ApiErrorCode.serverError,
      );
    } on SocketException {
      throw ApiException.offline();
    } on http.ClientException {
      throw ApiException.offline();
    } on TimeoutException {
      throw ApiException.timeout;
    } on ApiException {
      rethrow;
    } on SessionEpochInvalidated {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Invalid refresh response',
        errorCode: ApiErrorCode.serverError,
      );
    }
  }

  // Every authenticated endpoint crosses this one transport primitive.
  static Future<AuthenticatedResponse> _authenticatedRequest(
    AuthenticatedRequest request,
    _ApiAuthenticatedOperation operation,
  ) async {
    try {
      operation.guard.assertCurrent();
      var response = await _sendAuthenticated(request, operation);
      if (response.statusCode == 401) {
        operation.guard.assertCurrent();
        final refreshResult = await _tryRefreshToken(operation);
        operation.guard.assertCurrent();
        if (refreshResult == _RefreshResult.refreshed) {
          response = await _sendAuthenticated(request, operation);
        } else if (refreshResult == _RefreshResult.terminalFailure) {
          await _terminateExpiredSession();
          throw ApiException.sessionExpired();
        }
      }
      operation.guard.assertCurrent();
      if (response.statusCode == 401) {
        await _terminateExpiredSession();
        throw ApiException.sessionExpired();
      }
      return response;
    } on SocketException {
      throw ApiException.offline();
    } on TimeoutException {
      throw ApiException.timeout;
    }
  }

  static Future<AuthenticatedResponse> _sendAuthenticated(
    AuthenticatedRequest request,
    _ApiAuthenticatedOperation operation,
  ) async {
    operation.guard.assertCurrent();
    final authority = await _readOperationAuthority(operation);
    final headers = _authHeadersForAccessToken(authority.accessToken);
    headers.remove('Content-Type');
    final outgoing = await _buildAuthenticatedRequest(request);
    outgoing.headers.addAll(headers);
    outgoing.headers.addAll(request.headers);
    final Future<http.StreamedResponse> responseFuture;
    if (request.bodyKind == AuthenticatedBodyKind.stream) {
      final streamedRequest = outgoing as http.StreamedRequest;
      operation.guard.assertCurrent();
      responseFuture = _httpClient.send(streamedRequest);
      await streamedRequest.sink.addStream(request.streamFactory!());
      await streamedRequest.sink.close();
    } else {
      operation.guard.assertCurrent();
      responseFuture = _httpClient.send(outgoing);
    }
    final streamed = await responseFuture.timeout(request.timeout);
    final buffered = await http.Response.fromStream(streamed);
    operation.guard.assertCurrent();
    return AuthenticatedResponse(
      statusCode: buffered.statusCode,
      body: buffered.body,
      bodyBytes: buffered.bodyBytes,
      headers: buffered.headers,
    );
  }

  static Future<void> _requireSession(
    _ApiAuthenticatedOperation operation,
  ) async {
    await _readOperationAuthority(operation);
  }

  static Future<AuthSessionEnvelope> _readOperationAuthority(
    _ApiAuthenticatedOperation operation,
  ) async {
    operation.guard.assertCurrent();
    final authority = await _authSessionReader();
    operation.guard.assertCurrent();
    if (authority == null) {
      throw ApiException.authenticationRequired();
    }
    final boundUserId = operation.boundUserId;
    final boundEmail = operation.boundEmail;
    if (boundUserId == null && boundEmail == null) {
      operation.boundUserId = authority.userId;
      operation.boundEmail = authority.email;
      return authority;
    }
    if (boundUserId != authority.userId || boundEmail != authority.email) {
      throw const SessionEpochInvalidated();
    }
    return authority;
  }

  static Future<http.BaseRequest> _buildAuthenticatedRequest(
    AuthenticatedRequest request,
  ) async {
    final method = request.method.name.toUpperCase();
    switch (request.bodyKind) {
      case AuthenticatedBodyKind.multipart:
        final multipart = http.MultipartRequest(method, request.uri)
          ..fields.addAll(request.multipartFields);
        for (final part in request.multipartFiles) {
          final path = part.path;
          if (path != null) {
            multipart.files.add(
              await http.MultipartFile.fromPath(
                part.field,
                path,
                filename: part.filename,
              ),
            );
          } else {
            multipart.files.add(
              http.MultipartFile.fromBytes(
                part.field,
                part.bytes!,
                filename: part.filename,
              ),
            );
          }
        }
        return multipart;
      case AuthenticatedBodyKind.stream:
        final streamed = http.StreamedRequest(method, request.uri)
          ..contentLength = request.contentLength!;
        final contentType = request.contentType;
        if (contentType != null) streamed.headers['Content-Type'] = contentType;
        return streamed;
      case AuthenticatedBodyKind.empty:
      case AuthenticatedBodyKind.json:
      case AuthenticatedBodyKind.text:
        final buffered = http.Request(method, request.uri);
        if (request.bodyKind == AuthenticatedBodyKind.empty) {
          buffered.headers['Content-Type'] = 'application/json';
        }
        if (request.bodyKind == AuthenticatedBodyKind.json) {
          buffered.body = jsonEncode(request.jsonBody);
        } else if (request.bodyKind == AuthenticatedBodyKind.text) {
          buffered.body = request.textBody!;
        }
        final contentType = request.contentType;
        if (contentType != null) buffered.headers['Content-Type'] = contentType;
        return buffered;
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    final operation = authenticatedTransport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.get(Uri.parse('$baseUrl$endpoint')),
    );
    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'GET $endpoint failed'),
      statusCode: response.statusCode,
    );
  }

  static Future<String> getText(String endpoint) async {
    final operation = authenticatedTransport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.get(Uri.parse('$baseUrl$endpoint')),
    );
    if (response.statusCode == 200) return response.body;
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'GET $endpoint failed'),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final operation = authenticatedTransport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.post,
        Uri.parse('$baseUrl$endpoint'),
        data,
      ),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Request failed'),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final operation = authenticatedTransport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.put,
        Uri.parse('$baseUrl$endpoint'),
        data,
      ),
    );
    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Request failed'),
      statusCode: response.statusCode,
    );
  }

  static Future<void> delete(String endpoint) async {
    final operation = authenticatedTransport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.empty(
        AuthenticatedHttpMethod.delete,
        Uri.parse('$baseUrl$endpoint'),
      ),
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Request failed'),
      statusCode: response.statusCode,
    );
  }

  // ========== AUTH ENDPOINTS ==========

  /// Register a new user
  /// Returns: { token: string, user: { id, email, display_name? } }
  static Future<Map<String, dynamic>> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _publicHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Registration failed'),
      statusCode: response.statusCode,
    );
  }

  /// Login with email and password
  /// Returns: { token: string, user: { id, email, display_name? } }
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _publicHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Login failed'),
      statusCode: response.statusCode,
    );
  }

  /// Send a magic link to the given email address.
  /// Returns: { message: "..." }
  static Future<Map<String, dynamic>> sendMagicLink(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/magic-link/send'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Failed to send magic link'),
      statusCode: response.statusCode,
    );
  }

  /// Verify a magic link token and return JWT.
  /// Returns: { accessToken: "...", tokenType: "bearer" }
  static Future<Map<String, dynamic>> verifyMagicLink(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/magic-link/verify'),
      headers: _publicHeaders(),
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body,
          fallback: 'Magic link verification failed'),
      statusCode: response.statusCode,
    );
  }

  /// Verify an Apple identity token with the backend.
  /// Returns: { accessToken, tokenType, userId, email }
  static Future<Map<String, dynamic>> postAppleVerify({
    required String identityToken,
    required String nonce,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/apple/verify'),
      headers: _publicHeaders(),
      body: jsonEncode({
        'identityToken': identityToken,
        'nonce': nonce,
      }),
    );

    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(response.body,
          fallback: 'Apple Sign-In verification failed'),
      statusCode: response.statusCode,
    );
  }

  /// Get current user info
  /// Returns: { id, email, display_name?, created_at }
  static Future<Map<String, dynamic>> getMe() async {
    return get('/auth/me');
  }

  /// Resolves the identity for a just-verified magic-link token without
  /// publishing that token to secure storage or the shared auth transport.
  ///
  /// This one-shot request is epoch-guarded but deliberately has no refresh or
  /// terminal-session side effect: there is no complete authenticated session
  /// until the caller validates the returned identity and persists one atomic
  /// credential envelope.
  static Future<Map<String, dynamic>> getMeWithEphemeralAccessToken(
    String accessToken,
  ) async {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'must be non-empty',
      );
    }
    final epoch = _sessionEpoch;
    if (epoch == null) throw StateError('Session epoch is not bound');
    final guard = epoch.capture();
    try {
      guard.assertCurrent();
      final headers = _publicHeaders()
        ..['Authorization'] = 'Bearer $accessToken';
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/auth/me'), headers: headers)
          .timeout(const Duration(seconds: 15));
      guard.assertCurrent();
      if (response.statusCode != 200) {
        throw ApiException(
          'Magic-link identity resolution failed',
          statusCode: response.statusCode,
        );
      }
      final decoded =
          _safeJsonDecode(response.body, statusCode: response.statusCode);
      if (decoded is! Map) {
        throw ApiException(
          'Invalid identity response',
          statusCode: response.statusCode,
          errorCode: ApiErrorCode.serverError,
        );
      }
      guard.assertCurrent();
      return Map<String, dynamic>.from(decoded);
    } on SocketException {
      throw ApiException.offline();
    } on http.ClientException {
      throw ApiException.offline();
    } on TimeoutException {
      throw ApiException.timeout;
    }
  }

  static Future<void> deleteAccount() async {
    await delete('/auth/account');
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password-reset/request'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(
        response.body,
        fallback: 'Password reset request failed',
      ),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> confirmPasswordReset(
    String token,
    String newPassword,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password-reset/confirm'),
      headers: _publicHeaders(),
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(
        response.body,
        fallback: 'Password reset confirmation failed',
      ),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> requestEmailVerification(
    String email,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/email-verification/request'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(
        response.body,
        fallback: 'Email verification request failed',
      ),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> confirmEmailVerification(
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/email-verification/confirm'),
      headers: _publicHeaders(),
      body: jsonEncode({'token': token}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(
        response.body,
        fallback: 'Email verification failed',
      ),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> getAdminObservability() async {
    return get('/auth/admin/observability');
  }

  static Future<Map<String, dynamic>> getAdminOnboardingQuality({
    int days = 30,
  }) async {
    return get('/auth/admin/onboarding-quality?days=$days');
  }

  static Future<Map<String, dynamic>> getAdminOnboardingQualityCohorts({
    int days = 30,
  }) async {
    return get('/auth/admin/onboarding-quality/cohorts?days=$days');
  }

  static Future<String> exportAdminCohortsCsv({
    int days = 30,
  }) async {
    return getText('/auth/admin/cohorts/export.csv?days=$days');
  }

  // ========== ONBOARDING / ARBITRAGE (S31-S32) ==========

  static Future<MinimalProfileResult> computeMinimalProfile({
    required int age,
    required double grossSalary,
    required String canton,
    String? householdType,
    double? currentSavings,
    bool? isPropertyOwner,
    double? existing3a,
    double? existingLpp,
    String? lppCaisseType,
    double? totalDebts,
    double? monthlyDebtService,
  }) async {
    final response = await post('/onboarding/minimal-profile', {
      'age': age,
      'gross_salary': grossSalary,
      'canton': canton,
      if (householdType != null) 'household_type': householdType,
      if (currentSavings != null) 'current_savings': currentSavings,
      if (isPropertyOwner != null) 'is_property_owner': isPropertyOwner,
      if (existing3a != null) 'existing_3a': existing3a,
      if (existingLpp != null) 'existing_lpp': existingLpp,
      if (lppCaisseType != null) 'lpp_caisse_type': lppCaisseType,
      if (totalDebts != null) 'total_debts': totalDebts,
      if (monthlyDebtService != null)
        'monthly_debt_service': monthlyDebtService,
    });

    return parseMinimalProfileResponse(
      response,
      age: age,
      grossSalary: grossSalary,
      canton: canton,
      householdType: householdType,
      currentSavings: currentSavings,
      isPropertyOwner: isPropertyOwner,
      existing3a: existing3a,
      existingLpp: existingLpp,
    );
  }

  /// Parses the backend response without promoting illustrative AVS amounts.
  ///
  /// The backend endpoint does not yet return a reviewed, owner-scoped official
  /// pension envelope. Its AVS-derived totals therefore stay unavailable.
  @visibleForTesting
  static MinimalProfileResult parseMinimalProfileResponse(
    Map<String, dynamic> response, {
    required int age,
    required double grossSalary,
    required String canton,
    String? householdType,
    double? currentSavings,
    bool? isPropertyOwner,
    double? existing3a,
    double? existingLpp,
  }) {
    final estimatedMonthlyExpenses = _readDouble(
      response,
      const ['estimatedMonthlyExpenses', 'estimated_monthly_expenses'],
    );
    final monthsLiquidity = _readDouble(
      response,
      const ['monthsLiquidity', 'months_liquidity'],
    );
    final currentSavingsValue =
        currentSavings ?? (monthsLiquidity * estimatedMonthlyExpenses);
    final projectedLppMonthly = _readDouble(
      response,
      const ['projectedLppMonthly', 'projected_lpp_monthly'],
    );

    return MinimalProfileResult(
      avsMonthlyRente: null,
      lppAnnualRente: projectedLppMonthly * 12,
      lppMonthlyRente: projectedLppMonthly,
      totalMonthlyRetirement: null,
      grossMonthlySalary: grossSalary / 12,
      replacementRate: null,
      retirementGapMonthly: null,
      taxSaving3a: _readDouble(
        response,
        const ['taxSaving3a', 'tax_saving_3a'],
      ),
      marginalTaxRate: _readDouble(
        response,
        const ['marginalTaxRate', 'marginal_tax_rate'],
      ),
      currentSavings: currentSavingsValue,
      estimatedMonthlyExpenses: estimatedMonthlyExpenses,
      monthlyDebtImpact: _readDouble(
        response,
        const ['monthlyDebtImpact', 'monthly_debt_impact'],
      ),
      liquidityMonths: monthsLiquidity,
      canton: canton,
      age: age,
      grossAnnualSalary: grossSalary,
      householdType: householdType ?? 'single',
      isPropertyOwner: isPropertyOwner ?? false,
      existing3a: existing3a ?? 0,
      existingLpp: existingLpp ?? 0,
      employmentStatus: _readStringOrNull(
          response, const ['employmentStatus', 'employment_status']),
      nationalityGroup: _readStringOrNull(
          response, const ['nationalityGroup', 'nationality_group']),
      plafond3a: _readDoubleOrNull(response, const ['plafond3a', 'plafond_3a']),
      estimatedFields: _readStringList(
        response,
        const ['estimatedFields', 'estimated_fields'],
      ),
    );
  }

  static Future<PremierEclairage> computeOnboardingPremierEclairage({
    required int age,
    required double grossSalary,
    required String canton,
    String? householdType,
    double? currentSavings,
    bool? isPropertyOwner,
    double? existing3a,
    double? existingLpp,
    String? lppCaisseType,
    double? totalDebts,
    double? monthlyDebtService,
    String? stressType,
  }) async {
    final response = await post('/onboarding/premier-eclairage', {
      'age': age,
      'gross_salary': grossSalary,
      'canton': canton,
      if (householdType != null) 'household_type': householdType,
      if (currentSavings != null) 'current_savings': currentSavings,
      if (isPropertyOwner != null) 'is_property_owner': isPropertyOwner,
      if (existing3a != null) 'existing_3a': existing3a,
      if (existingLpp != null) 'existing_lpp': existingLpp,
      if (lppCaisseType != null) 'lpp_caisse_type': lppCaisseType,
      if (totalDebts != null) 'total_debts': totalDebts,
      if (monthlyDebtService != null)
        'monthly_debt_service': monthlyDebtService,
      if (stressType != null) 'stress_type': stressType,
    });

    return parseOnboardingPremierEclairageResponse(
      response: response,
      grossSalary: grossSalary,
    );
  }

  /// Parses only the non-retirement Premier Éclairage categories supported by
  /// the reviewed minimal-onboarding contract.
  ///
  /// Unknown or quarantined backend categories are replaced by an hourly-rate
  /// insight derived from the declared gross salary. Their number, copy, and
  /// confidence are deliberately ignored.
  @visibleForTesting
  static PremierEclairage parseOnboardingPremierEclairageResponse({
    required Map<String, dynamic> response,
    required double grossSalary,
  }) {
    final backendCategory = _readStringOrNull(response, const ['category']);
    const supportedCategories = <String>{
      'liquidity',
      'tax_saving',
      'compound_growth',
      'hourly_rate',
    };
    final isSupported = supportedCategories.contains(backendCategory);
    final category = isSupported ? backendCategory! : 'hourly_rate';
    final backendPrimaryNumber = _readDouble(response, const [
      'primaryNumber',
      'primary_number',
    ]);
    final salaryDerivedHourlyRate =
        grossSalary.isFinite && grossSalary > 0 ? grossSalary / (52 * 40) : 0.0;
    final fallback = salaryDerivedHourlyRate;
    final primaryNumber = isSupported ? backendPrimaryNumber : fallback;

    final (type, title, iconName, colorKey, value) = switch (category) {
      'liquidity' => (
          PremierEclairageType.liquidityAlert,
          'Ta réserve de liquidité', // lint-ignore: API model has no BuildContext
          'warning_amber',
          'error',
          '${primaryNumber.toStringAsFixed(1)} mois',
        ),
      'tax_saving' => (
          PremierEclairageType.taxSaving3a,
          'Ton économie d\'impôt potentielle', // lint-ignore: API model has no BuildContext
          'savings',
          'success',
          '${chf.formatChfWithPrefix(primaryNumber)}/an',
        ),
      'compound_growth' => (
          PremierEclairageType.compoundGrowth,
          'Ton avantage temps', // lint-ignore: API model has no BuildContext
          'trending_up',
          'success',
          chf.formatChfWithPrefix(primaryNumber),
        ),
      _ => (
          PremierEclairageType.hourlyRate,
          'Ton salaire brut horaire', // lint-ignore: API model has no BuildContext
          'schedule',
          'info',
          'CHF\u00A0${primaryNumber.round()}/h',
        ),
    };

    final displayText = isSupported
        ? _readString(response, const ['displayText', 'display_text'])
        : '';
    final explanationText = isSupported
        ? _readString(response, const ['explanationText', 'explanation_text'])
        : '';
    final confidenceModeStr = isSupported
        ? _readString(
            response,
            const [
              'confidenceMode',
              'confidence_mode',
            ],
            fallback: 'factual')
        : 'factual';
    final confidenceMode = confidenceModeStr == 'pedagogical'
        ? PremierEclairageConfidence.pedagogical
        : PremierEclairageConfidence.factual;

    return PremierEclairage(
      type: type,
      value: value,
      rawValue: primaryNumber,
      title: title,
      subtitle: explanationText.isNotEmpty
          ? '$displayText $explanationText'
          : displayText,
      iconName: iconName,
      colorKey: colorKey,
      confidenceMode: confidenceMode,
    );
  }

  static Future<ArbitrageResult> compareRenteVsCapital({
    required double capitalLppTotal,
    required double capitalObligatoire,
    required double capitalSurobligatoire,
    required double renteAnnuelleProposee,
    required String canton,
    double tauxConversionObligatoire = lppTauxConversionMinDecimal,
    double tauxConversionSurobligatoire = 0.05,
    int ageRetraite = avsAgeReferenceHomme,
    double tauxRetrait = 0.04,
    double rendementCapital = 0.03,
    double inflation = 0.02,
    int horizon = 25,
    bool isMarried = false,
  }) async {
    final response = await post('/arbitrage/rente-vs-capital', {
      'capital_lpp_total': capitalLppTotal,
      'capital_obligatoire': capitalObligatoire,
      'capital_surobligatoire': capitalSurobligatoire,
      'rente_annuelle_proposee': renteAnnuelleProposee,
      'taux_conversion_obligatoire': tauxConversionObligatoire,
      'taux_conversion_surobligatoire': tauxConversionSurobligatoire,
      'canton': canton,
      'age_retraite': ageRetraite,
      'taux_retrait': tauxRetrait,
      'rendement_capital': rendementCapital,
      'inflation': inflation,
      'horizon': horizon,
      'is_married': isMarried,
    });

    final rawOptions = response['options'];
    final options = <TrajectoireOption>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) {
          options.add(_parseTrajectoireOption(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawSensitivity = response['sensitivity'];
    final sensitivity = <String, double>{};
    if (rawSensitivity is Map) {
      for (final entry in rawSensitivity.entries) {
        sensitivity[entry.key.toString()] =
            (entry.value as num?)?.toDouble() ?? 0;
      }
    }

    final breakeven = _readNullableInt(
      response,
      const ['breakevenYear', 'breakeven_year'],
    );

    // ── Derive hero fields from trajectory data ──
    // full_rente (option A) year-1 cashflow = annual net rente
    // full_capital (option B) year-1 cashflow = annual SWR withdrawal
    double renteNetMensuelle = 0;
    double capitalRetraitMensuel = 0;
    double impotCumulRente = 0;
    double impotRetraitCapital = 0;
    double renteReelleAn20 = 0;

    final renteOption = options.where((o) => o.id == 'full_rente').firstOrNull;
    final capitalOption =
        options.where((o) => o.id == 'full_capital').firstOrNull;

    if (renteOption != null && renteOption.trajectory.isNotEmpty) {
      renteNetMensuelle = renteOption.trajectory.first.annualCashflow / 12;
      impotCumulRente = renteOption.trajectory.last.cumulativeTaxDelta;
      // Year 20 real rente (if horizon >= 20)
      if (renteOption.trajectory.length >= 20) {
        renteReelleAn20 = renteOption.trajectory[19].annualCashflow;
      }
    }

    if (capitalOption != null && capitalOption.trajectory.isNotEmpty) {
      capitalRetraitMensuel =
          capitalOption.trajectory.first.annualCashflow / 12;
      impotRetraitCapital = capitalOption.trajectory.first.cumulativeTaxDelta;
    }

    // Capital exhaustion age
    int? capitalEpuiseAge;
    if (capitalOption != null && capitalOption.trajectory.length > 1) {
      final firstCashflow = capitalOption.trajectory.first.annualCashflow;
      for (int i = 1; i < capitalOption.trajectory.length; i++) {
        if (capitalOption.trajectory[i].annualCashflow <
            firstCashflow * ArbitrageEngine.capitalExhaustionCashflowRatio) {
          capitalEpuiseAge = capitalOption.trajectory[i].year;
          break;
        }
      }
    }

    return ArbitrageResult(
      options: options,
      breakevenYear: breakeven != null && breakeven >= 0 ? breakeven : null,
      premierEclairage: _readString(
        response,
        const ['premierEclairage'],
      ),
      displaySummary: _readString(
        response,
        const ['displaySummary', 'display_summary'],
      ),
      hypotheses: _readStringList(
        response,
        const ['hypotheses'],
      ),
      disclaimer: _readString(
        response,
        const ['disclaimer'],
      ),
      sources: _readStringList(
        response,
        const ['sources'],
      ),
      confidenceScore: _readDouble(
        response,
        const ['confidenceScore', 'confidence_score'],
      ),
      sensitivity: sensitivity,
      renteNetMensuelle: renteNetMensuelle,
      capitalRetraitMensuel: capitalRetraitMensuel,
      capitalEpuiseAge: capitalEpuiseAge,
      impotCumulRente: impotCumulRente,
      impotRetraitCapital: impotRetraitCapital,
      renteReelleAn20: renteReelleAn20,
    );
  }

  static TrajectoireOption _parseTrajectoireOption(Map<String, dynamic> item) {
    final rawTrajectory = item['trajectory'];
    final trajectory = <YearlySnapshot>[];
    if (rawTrajectory is List) {
      for (final point in rawTrajectory) {
        if (point is! Map) continue;
        final map = Map<String, dynamic>.from(point);
        trajectory.add(
          YearlySnapshot(
            year: _readInt(map, const ['year']),
            netPatrimony: _readDouble(
              map,
              const ['netPatrimony', 'net_patrimony'],
            ),
            annualCashflow: _readDouble(
              map,
              const ['annualCashflow', 'annual_cashflow'],
            ),
            cumulativeTaxDelta: _readDouble(
              map,
              const ['cumulativeTaxDelta', 'cumulative_tax_delta'],
            ),
          ),
        );
      }
    }

    return TrajectoireOption(
      id: _readString(item, const ['id']),
      label: _readString(item, const ['label']),
      trajectory: trajectory,
      terminalValue: _readDouble(
        item,
        const ['terminalValue', 'terminal_value'],
      ),
      cumulativeTaxImpact: _readDouble(
        item,
        const ['cumulativeTaxImpact', 'cumulative_tax_impact'],
      ),
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) return value;
    }
    return fallback;
  }

  static String? _readStringOrNull(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) return value;
    }
    return null;
  }

  static double _readDouble(
    Map<String, dynamic> data,
    List<String> keys, {
    double fallback = 0.0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
    }
    return fallback;
  }

  static double? _readDoubleOrNull(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static int _readInt(
    Map<String, dynamic> data,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.round();
    }
    return fallback;
  }

  static int? _readNullableInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.round();
    }
    return null;
  }

  static List<String> _readStringList(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value.whereType<String>().toList();
      }
    }
    return const [];
  }

  // F3: _formatChf removed — use centralized chf.formatChfWithPrefix()

  static Future<Map<String, dynamic>> claimLocalData({
    required int localDataVersion,
    required String deviceId,
    DateTime? updatedAt,
    Map<String, dynamic> wizardAnswers = const {},
    Map<String, dynamic> miniOnboarding = const {},
    Map<String, dynamic> budgetSnapshot = const {},
    List<Map<String, dynamic>> checkins = const [],
    AuthenticatedOperation? operation,
  }) async {
    // FIX-W11-1: Send ISO 8601 UTC timestamp for conflict resolution
    final payload = <String, dynamic>{
      'local_data_version': localDataVersion,
      'device_id': deviceId,
      'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'wizard_answers': wizardAnswers,
      'mini_onboarding': miniOnboarding,
      'budget_snapshot': budgetSnapshot,
      'checkins': checkins,
    };
    if (operation == null) {
      return post('/sync/claim-local-data', payload);
    }
    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.post,
        Uri.parse('$baseUrl/sync/claim-local-data'),
        payload,
      ),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response.body, statusCode: response.statusCode);
    }
    throw ApiException(
      _extractErrorDetail(
        response.body,
        fallback: 'Request failed',
      ),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> verifyApplePurchase({
    required String productId,
    required String transactionId,
    String? originalTransactionId,
    String? purchasedAtIso,
    String? expiresAtIso,
    bool isTrial = false,
    String? signedPayload,
  }) async {
    return post(
      '/billing/apple/verify',
      {
        'product_id': productId,
        'transaction_id': transactionId,
        if (originalTransactionId != null)
          'original_transaction_id': originalTransactionId,
        if (purchasedAtIso != null) 'purchased_at': purchasedAtIso,
        if (expiresAtIso != null) 'expires_at': expiresAtIso,
        'is_trial': isTrial,
        if (signedPayload != null) 'signed_payload': signedPayload,
      },
    );
  }

  static String _extractErrorDetail(
    String responseBody, {
    required String fallback,
  }) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) return detail;
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Legacy methods — kept for backward compatibility.
  // All data entry now goes through CoachProfile + chat.

  @Deprecated(
      'Use CoachProfile instead — this legacy method predates chat-central architecture')
  static Future<Profile> createProfile({
    int? birthYear,
    String? canton,
    required HouseholdType householdType,
    double? incomeNetMonthly,
    double? incomeGrossYearly,
    double? savingsMonthly,
    double? lppInsuredSalary,
    bool hasDebt = false,
    Goal goal = Goal.other,
  }) async {
    final response = await post(
      '/profiles',
      {
        'birthYear': birthYear,
        'canton': canton,
        'householdType': householdType.name,
        'incomeNetMonthly': incomeNetMonthly,
        'incomeGrossYearly': incomeGrossYearly,
        'savingsMonthly': savingsMonthly,
        'lppInsuredSalary': lppInsuredSalary,
        'hasDebt': hasDebt,
        'goal': goal.name,
      },
    );
    return Profile.fromJson(response);
  }

  static Future<Session> createSession({
    required String profileId,
    required Map<String, dynamic> answers,
    required List<String> selectedFocusKinds,
    String? selectedGoalTemplateId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: _publicHeaders(),
      body: jsonEncode({
        'profileId': profileId,
        'answers': answers,
        'selectedFocusKinds': selectedFocusKinds,
        'selectedGoalTemplateId': selectedGoalTemplateId,
      }),
    );

    if (response.statusCode == 200) {
      return Session.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        _extractErrorDetail(response.body,
            fallback: 'Failed to create session'),
        statusCode: response.statusCode,
      );
    }
  }
}
