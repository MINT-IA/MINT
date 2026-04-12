import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/notification_service.dart';

// ────────────────────────────────────────────────────────────
//  FRESH START SERVICE — Phase 14 / CMIT-03 + CMIT-04
//
//  API client for fresh-start landmark detection.
//  GET /api/v1/coach/fresh-start — upcoming landmarks with messages
//
//  Sources:
//    - CMIT-03: 5 landmark types per locked decision
//    - CMIT-04: 1 notification per landmark, max 2/month
// ────────────────────────────────────────────────────────────

/// A single fresh-start landmark with its personalized message.
class FreshStartLandmark {
  final String type;
  final String date;
  final int daysUntil;
  final String message;
  final String intent;

  const FreshStartLandmark({
    required this.type,
    required this.date,
    required this.daysUntil,
    required this.message,
    required this.intent,
  });

  factory FreshStartLandmark.fromJson(Map<String, dynamic> json) {
    return FreshStartLandmark(
      type: json['type'] as String? ?? '',
      date: json['date'] as String? ?? '',
      daysUntil: json['daysUntil'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      intent: json['intent'] as String? ?? '',
    );
  }
}

class FreshStartService {
  final String baseUrl;

  FreshStartService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiService.baseUrl;

  /// Fetch upcoming fresh-start landmarks from the backend.
  ///
  /// Returns a list of landmarks with personalized messages.
  /// Returns empty list on auth or network errors (non-critical feature).
  Future<List<FreshStartLandmark>> fetchLandmarks() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse('$baseUrl/coach/fresh-start');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final landmarks = data['landmarks'] as List<dynamic>? ?? [];
      return landmarks
          .map((e) =>
              FreshStartLandmark.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch landmarks and schedule local notifications for each.
  ///
  /// Client-side rate limit via SharedPreferences: max 2 per calendar
  /// month (UX backup — server already enforces this).
  ///
  /// Call on app startup after authentication is confirmed.
  Future<void> scheduleAllFreshStartNotifications() async {
    final landmarks = await fetchLandmarks();
    if (landmarks.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final monthKey = 'fresh_start_count_${now.year}_${now.month.toString().padLeft(2, '0')}';
    final currentCount = prefs.getInt(monthKey) ?? 0;

    if (currentCount >= 2) return; // Already hit monthly limit

    final notifService = NotificationService();
    var scheduled = 0;

    for (final landmark in landmarks) {
      if (currentCount + scheduled >= 2) break;

      final landmarkDate = DateTime.tryParse(landmark.date);
      if (landmarkDate == null) continue;

      await notifService.scheduleFreshStart(
        landmarkType: landmark.type,
        date: landmarkDate,
        title: 'MINT',
        body: landmark.message,
      );
      scheduled++;
    }

    // Persist updated count
    if (scheduled > 0) {
      await prefs.setInt(monthKey, currentCount + scheduled);
    }
  }
}
