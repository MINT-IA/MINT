import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const String _definedApiBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// Base URL candidates ordered by priority.
  /// Override with:
  ///   flutter run --dart-define=API_BASE_URL=https://<your-api>/api/v1
  static final List<String> _baseUrlCandidates = (() {
    final candidates = <String>[
      if (_definedApiBaseUrl.isNotEmpty) _definedApiBaseUrl,
      // Active Railway production domain (kept before legacy fallbacks).
      if (kReleaseMode) 'https://mint-production-3a41.up.railway.app/api/v1',
      if (kReleaseMode) 'https://api.mint.ch/api/v1',
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

  // Helper method to get auth headers with JWT token
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Attempt to refresh tokens using the stored refresh token.
  /// Returns true if refresh succeeded, false otherwise.
  static Future<bool> _tryRefreshToken() async {
    final refreshToken = await AuthService.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await AuthService.saveToken(
          data['access_token'],
          data['user_id'],
          data['email'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
    } catch (_) {
      // Refresh failed — user will need to re-login
    }
    return false;
  }

  // Méthodes génériques HTTP (now with JWT injection + auto-refresh)
  static Future<Map<String, dynamic>> get(String endpoint) async {
    var response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
    );

    // Auto-refresh on 401
    if (response.statusCode == 401 && await _tryRefreshToken()) {
      response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _authHeaders(),
      );
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('GET $endpoint failed: ${response.body}');
    }
  }

  static Future<String> getText(String endpoint) async {
    var response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _authHeaders(),
      );
    }

    if (response.statusCode == 200) {
      return response.body;
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'GET $endpoint failed'),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    var response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('POST $endpoint failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> data) async {
    var response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('PUT $endpoint failed: ${response.body}');
    }
  }

  static Future<void> delete(String endpoint) async {
    var response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _authHeaders(),
      );
    }

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('DELETE $endpoint failed: ${response.body}');
    }
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Login failed'),
      statusCode: response.statusCode,
    );
  }

  /// Get current user info
  /// Returns: { id, email, display_name?, created_at }
  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user info: ${response.body}');
    }
  }

  static Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/auth/account'),
      headers: await _authHeaders(),
    );
    if (response.statusCode == 200) return;
    throw ApiException(
      _extractErrorDetail(
        response.body,
        fallback: 'Account deletion failed',
      ),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password-reset/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
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

    final estimatedMonthlyExpenses = _readDouble(
      response,
      const ['estimatedMonthlyExpenses', 'estimated_monthly_expenses'],
    );
    final estimatedMonthlyRetirement = _readDouble(
      response,
      const ['estimatedMonthlyRetirement', 'estimated_monthly_retirement'],
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
      avsMonthlyRente: _readDouble(
        response,
        const ['projectedAvsMonthly', 'projected_avs_monthly'],
      ),
      lppAnnualRente: projectedLppMonthly * 12,
      lppMonthlyRente: projectedLppMonthly,
      totalMonthlyRetirement: estimatedMonthlyRetirement,
      grossMonthlySalary: grossSalary / 12,
      replacementRate: _readDouble(
        response,
        const ['estimatedReplacementRatio', 'estimated_replacement_ratio'],
      ),
      retirementGapMonthly: _readDouble(
        response,
        const ['retirementGapMonthly', 'retirement_gap_monthly'],
      ),
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
      employmentStatus: _readString(response, const ['employmentStatus', 'employment_status'], fallback: 'salarie'),
      nationalityGroup: _readString(response, const ['nationalityGroup', 'nationality_group'], fallback: 'CH'),
      plafond3a: _readDouble(response, const ['plafond3a', 'plafond_3a']),
      estimatedFields: _readStringList(
        response,
        const ['estimatedFields', 'estimated_fields'],
      ),
    );
  }

  static Future<ChiffreChoc> computeOnboardingChiffreChoc({
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
    final response = await post('/onboarding/chiffre-choc', {
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

    final category = _readString(
      response,
      const ['category'],
      fallback: 'retirement_gap',
    );
    final primaryNumber = _readDouble(
      response,
      const ['primaryNumber', 'primary_number'],
    );
    final displayText = _readString(
      response,
      const ['displayText', 'display_text'],
    );
    final explanationText = _readString(
      response,
      const ['explanationText', 'explanation_text'],
    );

    final type = switch (category) {
      'liquidity' => ChiffreChocType.liquidityAlert,
      'tax_saving' => ChiffreChocType.taxSaving3a,
      'retirement_gap' => ChiffreChocType.retirementGap,
      _ => ChiffreChocType.retirementIncome,
    };

    final (title, iconName, colorKey, value) = switch (type) {
      ChiffreChocType.liquidityAlert => (
          'Ta reserve de liquidite',
          'warning_amber',
          'error',
          '${primaryNumber.toStringAsFixed(1)} mois',
        ),
      ChiffreChocType.taxSaving3a => (
          'Ton economie d\'impot potentielle',
          'savings',
          'success',
          '${_formatChf(primaryNumber)}/an',
        ),
      ChiffreChocType.retirementGap => (
          'Ton ecart de retraite',
          'trending_down',
          'warning',
          '${_formatChf(primaryNumber)}/mois',
        ),
      ChiffreChocType.retirementIncome => (
          'Ton revenu estime a la retraite',
          'account_balance',
          'info',
          '${_formatChf(primaryNumber)}/mois',
        ),
    };

    return ChiffreChoc(
      type: type,
      value: value,
      rawValue: primaryNumber,
      title: title,
      subtitle: explanationText.isNotEmpty
          ? '$displayText $explanationText'
          : displayText,
      iconName: iconName,
      colorKey: colorKey,
    );
  }

  static Future<ArbitrageResult> compareRenteVsCapital({
    required double capitalLppTotal,
    required double capitalObligatoire,
    required double capitalSurobligatoire,
    required double renteAnnuelleProposee,
    required String canton,
    double tauxConversionObligatoire = 0.068,
    double tauxConversionSurobligatoire = 0.05,
    int ageRetraite = 65,
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

    return ArbitrageResult(
      options: options,
      breakevenYear: breakeven != null && breakeven >= 0 ? breakeven : null,
      chiffreChoc: _readString(
        response,
        const ['chiffreChoc', 'chiffre_choc'],
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

  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF ${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  static Future<Map<String, dynamic>> claimLocalData({
    required int localDataVersion,
    required String deviceId,
    Map<String, dynamic> wizardAnswers = const {},
    Map<String, dynamic> miniOnboarding = const {},
    Map<String, dynamic> budgetSnapshot = const {},
    List<Map<String, dynamic>> checkins = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sync/claim-local-data'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'local_data_version': localDataVersion,
        'device_id': deviceId,
        'wizard_answers': wizardAnswers,
        'mini_onboarding': miniOnboarding,
        'budget_snapshot': budgetSnapshot,
        'checkins': checkins,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw ApiException(
      _extractErrorDetail(response.body, fallback: 'Local data sync failed'),
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
    final response = await http.post(
      Uri.parse('$baseUrl/billing/apple/verify'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'product_id': productId,
        'transaction_id': transactionId,
        if (originalTransactionId != null)
          'original_transaction_id': originalTransactionId,
        if (purchasedAtIso != null) 'purchased_at': purchasedAtIso,
        if (expiresAtIso != null) 'expires_at': expiresAtIso,
        'is_trial': isTrial,
        if (signedPayload != null) 'signed_payload': signedPayload,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw ApiException(
      _extractErrorDetail(
        response.body,
        fallback: 'Apple purchase verification failed',
      ),
      statusCode: response.statusCode,
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

  // Méthodes spécifiques (legacy)
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
    final response = await http.post(
      Uri.parse('$baseUrl/profiles'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'birthYear': birthYear,
        'canton': canton,
        'householdType': householdType.name,
        'incomeNetMonthly': incomeNetMonthly,
        'incomeGrossYearly': incomeGrossYearly,
        'savingsMonthly': savingsMonthly,
        'lppInsuredSalary': lppInsuredSalary,
        'hasDebt': hasDebt,
        'goal': goal.name,
      }),
    );

    if (response.statusCode == 200) {
      return Profile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create profile: ${response.body}');
    }
  }

  static Future<Session> createSession({
    required String profileId,
    required Map<String, dynamic> answers,
    required List<String> selectedFocusKinds,
    String? selectedGoalTemplateId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
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
      throw Exception('Failed to create session: ${response.body}');
    }
  }

  static Future<SessionReport> getSessionReport(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sessions/$sessionId/report'),
    );

    if (response.statusCode == 200) {
      return SessionReport.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get session report: ${response.body}');
    }
  }
}
