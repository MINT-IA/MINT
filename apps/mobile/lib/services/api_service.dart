import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/profile.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8001/api/v1';

  // Méthodes génériques HTTP
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('DELETE $endpoint failed: ${response.body}');
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
