/// B2B Organization Service — Sprint S71-S72.
///
/// Manages employer/caisse organization membership for white-label B2B.
/// Employees join via invite code, organizations control enabled modules.
///
/// Privacy: NO PII stored in organization data. Employee opt-in only.
/// Outil éducatif — ne constitue pas un conseil financier (LSFin).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────────────────

/// Subscription plan for a B2B organization.
enum B2bPlan { starter, professional, enterprise }

/// Modules available per plan tier.
const Map<B2bPlan, List<String>> kPlanModules = {
  B2bPlan.starter: ['education'],
  B2bPlan.professional: ['education', 'wellness', '3a'],
  B2bPlan.enterprise: ['education', 'wellness', '3a', 'lpp'],
};

/// A B2B organization (employer or caisse de pension).
class B2bOrganization {
  final String id;
  final String name;
  final String? logoUrl;
  final B2bPlan plan;
  final int employeeCount;
  final List<String> enabledModules;
  final String primaryColor;
  final String contactEmail;
  final DateTime contractStart;
  final DateTime? contractEnd;

  const B2bOrganization({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.plan,
    required this.employeeCount,
    required this.enabledModules,
    required this.primaryColor,
    required this.contactEmail,
    required this.contractStart,
    this.contractEnd,
  });

  /// Serialize to JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'plan': plan.name,
        'employeeCount': employeeCount,
        'enabledModules': enabledModules,
        'primaryColor': primaryColor,
        'contactEmail': contactEmail,
        'contractStart': contractStart.toIso8601String(),
        if (contractEnd != null)
          'contractEnd': contractEnd!.toIso8601String(),
      };

  /// Deserialize from JSON map.
  factory B2bOrganization.fromJson(Map<String, dynamic> json) {
    return B2bOrganization(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
      plan: B2bPlan.values.firstWhere(
        (p) => p.name == json['plan'],
        orElse: () => B2bPlan.starter,
      ),
      employeeCount: json['employeeCount'] as int? ?? 0,
      enabledModules: (json['enabledModules'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      primaryColor: json['primaryColor'] as String? ?? '#1D1D1F',
      contactEmail: json['contactEmail'] as String? ?? '',
      contractStart: DateTime.parse(json['contractStart'] as String),
      contractEnd: json['contractEnd'] != null
          ? DateTime.parse(json['contractEnd'] as String)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Invite code registry (stub — production uses backend API)
// ─────────────────────────────────────────────────────────────────────

/// Known invite codes → organizations (stub for offline/demo).
/// In production, invite codes are validated via backend API.
final Map<String, B2bOrganization> kInviteCodeRegistry = {
  'MINT-DEMO-2026': B2bOrganization(
    id: 'org_demo_001',
    name: 'MINT Demo Corp',
    plan: B2bPlan.professional,
    employeeCount: 50,
    enabledModules: ['education', 'wellness', '3a'],
    primaryColor: '#1D1D1F',
    contactEmail: 'demo@mint-app.ch',
    contractStart: DateTime(2026, 1, 1),
  ),
};

// ─────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────

/// SharedPreferences key for B2B organization data.
const String kB2bOrgKey = '_b2b_organization';

/// Service for B2B organization management.
///
/// Employees join via invite code. Organization data is persisted locally.
/// No PII is stored in the organization record.
class B2bOrganizationService {
  B2bOrganizationService._();

  // ═══════════════════════════════════════════════════════════════
  //  Organization management
  // ═══════════════════════════════════════════════════════════════

  /// Get the current organization membership, or null if not joined.
  static Future<B2bOrganization?> getOrganization({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final raw = sp.getString(kB2bOrgKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return B2bOrganization.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Join an organization using an invite code.
  ///
  /// Throws [ArgumentError] if the invite code is invalid.
  static Future<void> joinOrganization({
    required String inviteCode,
    SharedPreferences? prefs,
  }) async {
    final org = kInviteCodeRegistry[inviteCode.trim().toUpperCase()];
    if (org == null) {
      throw ArgumentError(
        'Code d\u2019invitation invalide\u00a0: $inviteCode',
      );
    }
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setString(kB2bOrgKey, jsonEncode(org.toJson()));
  }

  /// Leave the current organization. Clears all B2B data.
  static Future<void> leaveOrganization({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(kB2bOrgKey);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Module access
  // ═══════════════════════════════════════════════════════════════

  /// Check whether a specific module is enabled for the organization.
  static bool isModuleEnabled(B2bOrganization org, String module) {
    return org.enabledModules.contains(module);
  }

  /// List all modules available to the organization based on plan + overrides.
  static List<String> availableModules(B2bOrganization org) {
    final planModules = kPlanModules[org.plan] ?? const [];
    // Intersection: only modules both in plan AND explicitly enabled.
    return planModules
        .where((m) => org.enabledModules.contains(m))
        .toList();
  }
}
