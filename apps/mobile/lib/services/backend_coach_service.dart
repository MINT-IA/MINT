import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';

// ────────────────────────────────────────────────────────────
//  BACKEND COACH SERVICE — S56
// ────────────────────────────────────────────────────────────
//
//  Calls the MINT backend Claude proxy instead of direct BYOK.
//  The API key stays server-side (Railway secret).
//
//  Flow: Flutter → POST /api/v1/coach/chat → Backend → Claude → response
//
//  Fallback: if backend is unreachable, returns null so the
//  caller can fall back to SLM or templates.
// ────────────────────────────────────────────────────────────

class WidgetCall {
  final String tool;
  final Map<String, dynamic> params;
  const WidgetCall({required this.tool, required this.params});
}

class BackendCoachResponse {
  final String reply;
  final String disclaimer;
  final String model;
  final int tokensUsed;
  final int remainingQuota;
  final WidgetCall? widget;

  const BackendCoachResponse({
    required this.reply,
    required this.disclaimer,
    required this.model,
    required this.tokensUsed,
    required this.remainingQuota,
    this.widget,
  });
}

class BackendCoachService {
  BackendCoachService._();

  /// Base URL for the MINT backend.
  /// In production: https://mint-production-3a41.up.railway.app
  /// In dev: http://localhost:8080
  static String get _baseUrl {
    // Use production URL. For local dev, override via env or const.
    const prodUrl = 'https://mint-production-3a41.up.railway.app';
    return prodUrl;
  }

  /// Send a message to the backend Claude proxy.
  ///
  /// Returns null if the backend is unreachable (caller should fallback).
  static Future<BackendCoachResponse?> chat({
    required String message,
    required CoachProfile profile,
    required List<Map<String, String>> history,
    BudgetSnapshot? budgetSnapshot,
  }) async {
    try {
      // Load CapMemory for coach context
      final capMemory = await CapMemoryStore.load();

      final body = {
        'message': message,
        'conversationHistory': history.take(20).toList(),
        'firstName': profile.firstName,
        'age': profile.age,
        'canton': profile.canton,
        'salaryAnnual': profile.revenuBrutAnnuel,
        'civilStatus': profile.etatCivil.name,
        'archetype': profile.archetype.name,
        'financialLiteracyLevel': profile.financialLiteracyLevel.name,
        'friTotal': null, // injected if available
        'replacementRatio': null, // injected if available
        'confidenceScore': null,
        'avoirLpp': profile.prevoyance.avoirLppTotal,
        'epargne3a': profile.prevoyance.totalEpargne3a,
        'totalDettes': profile.dettes.totalDettes,
        // CapMemory context
        'lastCapServed': capMemory.lastCapServed,
        'completedActions': capMemory.completedActions,
        'abandonedFlows': capMemory.abandonedFlows,
        'declaredGoals': capMemory.declaredGoals,
        // BudgetSnapshot context (optional — null if engine not yet available)
        if (budgetSnapshot != null) ...{
          'presentFree': budgetSnapshot.present.monthlyFree,
          'retirementFree': budgetSnapshot.retirement?.monthlyNet,
          'gap': budgetSnapshot.gap?.monthlyGap,
          'budgetConfidenceScore': budgetSnapshot.confidenceScore,
        },
        'planned_contributions': profile.plannedContributions
            .map((c) => {
                  'id': c.id,
                  'label': c.label,
                  'amount': c.amount,
                  'category': c.category,
                })
            .toList(),
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/coach/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse widget tool call if Claude chose one
        WidgetCall? widget;
        if (data['widget'] != null) {
          final w = data['widget'];
          widget = WidgetCall(
            tool: w['tool'] ?? '',
            params: Map<String, dynamic>.from(w['params'] ?? {}),
          );
        }

        return BackendCoachResponse(
          reply: data['reply'] ?? '',
          disclaimer: data['disclaimer'] ?? '',
          model: data['usedModel'] ?? '',
          tokensUsed: data['tokensUsed'] ?? 0,
          remainingQuota: data['remainingQuota'] ?? -1,
          widget: widget,
        );
      }

      debugPrint('[BackendCoach] HTTP ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[BackendCoach] Error: $e');
      return null;
    }
  }
}
