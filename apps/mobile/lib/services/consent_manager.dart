/// Consent Manager — Sprint S40.
///
/// Manages 3 independent, granular consents (nLPD compliant):
///   1. BYOK data sharing (CoachContext -> LLM provider)
///   2. Snapshot storage (longitudinal tracking)
///   3. Notifications (personalized push)
///
/// Each consent: independent, revocable immediately.
/// All OFF by default (privacy by design, nLPD art. 6).
///
/// Sources:
/// - LPD art. 6 (principes de traitement)
/// - nLPD art. 5 let. f (profilage)
/// - LSFin art. 3 (information financiere)
library;

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  CONSENT MANAGER — S40 / Reengagement + Consent
// ────────────────────────────────────────────────────────────
//
// Trois consentements granulaires, independants, revocables :
//
// 1. byokDataSharing  — Envoi des donnees agregees au fournisseur IA
// 2. snapshotStorage   — Conservation de l'historique de projections
// 3. notifications     — Rappels personnalises avec chiffres
//
// Tous OFF par defaut (privacy by design).
// Revocation immediate sans consequence sur le service de base.
// ────────────────────────────────────────────────────────────

/// The independent consent types.
enum ConsentType {
  /// BYOK data sharing: CoachContext fields sent to LLM provider.
  byokDataSharing,

  /// Snapshot storage: longitudinal tracking of projection results.
  snapshotStorage,

  /// Notifications: personalized push with financial numbers.
  notifications,

  /// Analytics: anonymous event tracking for product improvement.
  analytics,

  /// RAG queries: knowledge-base queries for coach personalization.
  ragQueries,
}

/// State of a single consent toggle.
class ConsentState {
  /// Which consent this represents.
  final ConsentType type;

  /// Whether the consent is currently enabled.
  final bool enabled;

  /// Short French label for the toggle.
  final String label;

  /// Detailed description of what exactly is shared/stored.
  final String detail;

  /// Privacy reassurance: what is NEVER sent/stored.
  final String neverSent;

  const ConsentState({
    required this.type,
    required this.enabled,
    required this.label,
    required this.detail,
    required this.neverSent,
  });

  /// Create a copy with a different enabled state.
  ConsentState copyWith({bool? enabled}) {
    return ConsentState(
      type: type,
      enabled: enabled ?? this.enabled,
      label: label,
      detail: detail,
      neverSent: neverSent,
    );
  }
}

/// Dashboard grouping all 3 consents with legal references.
class ConsentDashboard {
  /// The 3 independent consent states.
  final List<ConsentState> consents;

  /// Legal disclaimer (nLPD art. 6).
  final String disclaimer;

  /// Legal source references.
  final List<String> sources;

  const ConsentDashboard({
    required this.consents,
    required this.disclaimer,
    required this.sources,
  });

  /// Create a copy with one consent toggled.
  ConsentDashboard copyWithToggled(ConsentType type, bool enabled) {
    return ConsentDashboard(
      consents: consents.map((c) {
        if (c.type == type) return c.copyWith(enabled: enabled);
        return c;
      }).toList(),
      disclaimer: disclaimer,
      sources: sources,
    );
  }

  /// Create a copy with all consents revoked (all OFF).
  ConsentDashboard copyWithAllRevoked() {
    return ConsentDashboard(
      consents: consents.map((c) => c.copyWith(enabled: false)).toList(),
      disclaimer: disclaimer,
      sources: sources,
    );
  }
}

/// Consent manager with local persistence via SharedPreferences.
///
/// Provides default consent dashboard and BYOK field detail.
/// All consents are OFF by default (privacy by design, nLPD art. 6).
/// Consent state is persisted locally and restored on app restart.
class ConsentManager {
  ConsentManager._();

  static const _prefix = 'consent_';

  /// Check if a specific consent is enabled (from SharedPreferences).
  static Future<bool> isConsentGiven(ConsentType type) async {
    final prefs = await _getPrefs();
    return prefs.getBool('$_prefix${type.name}') ?? false;
  }

  /// Update a single consent and persist it.
  static Future<void> updateConsent(ConsentType type, bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool('$_prefix${type.name}', enabled);
  }

  /// Revoke all consents.
  static Future<void> revokeAll() async {
    final prefs = await _getPrefs();
    for (final type in ConsentType.values) {
      await prefs.setBool('$_prefix${type.name}', false);
    }
  }

  /// Load dashboard with persisted consent state.
  ///
  /// Pass [l] to get localized labels; falls back to French strings if null.
  static Future<ConsentDashboard> loadDashboard({S? l}) async {
    final dashboard = getDefaultDashboard(l: l);
    final prefs = await _getPrefs();
    return ConsentDashboard(
      consents: dashboard.consents.map((c) {
        final persisted = prefs.getBool('$_prefix${c.type.name}') ?? false;
        return c.copyWith(enabled: persisted);
      }).toList(),
      disclaimer: dashboard.disclaimer,
      sources: dashboard.sources,
    );
  }

  static Future<SharedPreferences> _getPrefs() async {
    return SharedPreferences.getInstance();
  }

  /// Returns default consent dashboard (all OFF).
  ///
  /// Pass [l] to get localized labels; falls back to French strings if null.
  static ConsentDashboard getDefaultDashboard({S? l}) {
    return ConsentDashboard(
      consents: [
        ConsentState(
          type: ConsentType.byokDataSharing,
          enabled: false,
          label: l?.consentLabelByok ?? 'Personnalisation IA',
          detail: 'Envoyer tes donnees financieres agregees a ton fournisseur IA '
              'pour personnaliser les textes du coach.',
          neverSent: 'Ton salaire exact, tes soldes bancaires, ton employeur, '
              'ton adresse et tes donnees familiales ne sont jamais envoyes.',
        ),
        ConsentState(
          type: ConsentType.snapshotStorage,
          enabled: false,
          label: l?.consentLabelSnapshot ?? 'Historique de progression',
          detail: 'Conserver l\'historique de tes projections pour suivre '
              'ta progression dans le temps.',
          neverSent: 'Tes donnees brutes ne sont pas stockees. '
              'Seuls les resultats agreges sont conserves.',
        ),
        ConsentState(
          type: ConsentType.notifications,
          enabled: false,
          label: l?.consentLabelNotifications ?? 'Rappels personnalises',
          detail: 'Recevoir des rappels avec tes chiffres personnels '
              '(3a, impots, check-in).',
          neverSent: 'Aucune notification ne contient ton salaire, '
              'tes soldes ou tes donnees sensibles.',
        ),
      ],
      disclaimer: l?.consentDashboardDisclaimer ??
          'Tes donnees t\'appartiennent. Chaque parametre est '
          'revocable a tout moment (nLPD art. 6).',
      sources: const [
        'LPD art. 6 (principes de traitement)',
        'nLPD art. 5 let. f (profilage)',
        'LSFin art. 3 (information financiere)',
      ],
    );
  }

  /// Check consent before performing a sensitive action.
  ///
  /// Returns true if the consent is given, false otherwise.
  /// Use this before creating snapshots, sending BYOK, or scheduling notifs.
  static Future<bool> guardConsent(ConsentType type) async {
    return isConsentGiven(type);
  }

  /// Get BYOK detail: exactly which fields are sent vs never sent.
  ///
  /// Returns a map with two keys:
  ///   - 'sent': list of field names transmitted to the LLM provider
  ///   - 'neverSent': list of data categories that are never shared
  static Map<String, List<String>> getByokDetail() {
    return const {
      'sent': [
        'firstName',
        'archetype',
        'age',
        'canton',
        'friTotal',
        'friDelta',
        'replacementRatio',
        'monthsLiquidity',
        'taxSavingPotential',
        'confidenceScore',
        'daysSinceLastVisit',
        'fiscalSeason',
      ],
      'neverSent': [
        'salaire exact',
        'soldes bancaires',
        'montants de dette',
        'noms de banque',
        'employeur',
        'NPA / adresse',
        'noms des membres de la famille',
      ],
    };
  }
}

// In-memory fallback removed — consent now persists via SharedPreferences
// to survive app restarts (V5-1 audit fix).
