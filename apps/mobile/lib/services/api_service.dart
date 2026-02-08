import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/services/auth_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8888/api/v1';

  // Helper method to get auth headers with JWT token
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Méthodes génériques HTTP (now with JWT injection)
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('GET $endpoint failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('POST $endpoint failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('PUT $endpoint failed: ${response.body}');
    }
  }

  static Future<void> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _authHeaders(),
    );

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
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['detail'] ?? 'Registration failed');
    }
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
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['detail'] ?? 'Login failed');
    }
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
