/// Consent Manager — Sprint S40 + F3-4 audit fix.
///
/// Manages 7 independent, granular consents (nLPD compliant):
///   1. BYOK data sharing (CoachContext -> LLM provider)
///   2. Snapshot storage (longitudinal tracking)
///   3. Notifications (personalized push)
///   4. Analytics (anonymous event tracking)
///   5. RAG queries (coach knowledge-base queries)
///   6. Open Banking (bLink/SFTI connection)
///   7. Document Upload (OCR scanning)
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
// Sept consentements granulaires, indépendants, révocables :
//
// 1. byokDataSharing  — Envoi des données agrégées au fournisseur IA
// 2. snapshotStorage   — Conservation de l'historique de projections
// 3. notifications     — Rappels personnalisés avec chiffres
// 4. analytics         — Statistiques anonymisées
// 5. ragQueries        — Questions posées au coach IA
// 6. openBanking       — Connexion lecture seule aux comptes
// 7. documentUpload    — Certificats et relevés analysés par OCR
//
// Tous OFF par défaut (privacy by design).
// Révocation immédiate sans conséquence sur le service de base.
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

  /// Open Banking: bLink/SFTI connection for transaction import.
  openBanking,

  /// Document Upload: OCR scanning and certificate storage.
  documentUpload,
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

/// Dashboard grouping all 7 consents with legal references.
class ConsentDashboard {
  /// The 7 independent consent states (one per ConsentType).
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

  /// Returns default consent dashboard with ALL 7 consent types (all OFF).
  ///
  /// F3-4: Dashboard MUST include every ConsentType value so that
  /// loadDashboard() can persist/restore all consent states.
  ///
  /// Pass [l] to get localized labels; falls back to French strings if null.
  static ConsentDashboard getDefaultDashboard({S? l}) {
    return ConsentDashboard(
      consents: [
        ConsentState(
          type: ConsentType.byokDataSharing,
          enabled: false,
          label: l?.consentLabelByok ?? 'Personnalisation IA',
          detail: 'Envoyer tes données financières agrégées à ton fournisseur IA '
              'pour personnaliser les textes du coach.',
          neverSent: 'Ton salaire exact, tes soldes bancaires, ton employeur, '
              'ton adresse et tes données familiales ne sont jamais envoyés.',
        ),
        ConsentState(
          type: ConsentType.snapshotStorage,
          enabled: false,
          label: l?.consentLabelSnapshot ?? 'Historique de progression',
          detail: 'Conserver l\'historique de tes projections pour suivre '
              'ta progression dans le temps.',
          neverSent: 'Tes données brutes ne sont pas stockées. '
              'Seuls les résultats agrégés sont conservés.',
        ),
        ConsentState(
          type: ConsentType.notifications,
          enabled: false,
          label: l?.consentLabelNotifications ?? 'Rappels personnalisés',
          detail: 'Recevoir des rappels avec tes chiffres personnels '
              '(3a, impôts, check-in).',
          neverSent: 'Aucune notification ne contient ton salaire, '
              'tes soldes ou tes données sensibles.',
        ),
        const ConsentState(
          type: ConsentType.analytics,
          enabled: false,
          label: 'Analyse d\'utilisation',
          detail: 'Statistiques anonymisées pour améliorer l\'app.',
          neverSent: 'Aucune donnée personnelle n\'est incluse '
              'dans les statistiques agrégées.',
        ),
        const ConsentState(
          type: ConsentType.ragQueries,
          enabled: false,
          label: 'Questions à l\'assistant',
          detail: 'Historique des questions posées au coach IA '
              '(BYOK — ta propre cle API).',
          neverSent: 'Les questions ne contiennent ni ton salaire, '
              'ni tes soldes, ni tes données sensibles.',
        ),
        const ConsentState(
          type: ConsentType.openBanking,
          enabled: false,
          label: 'Données bancaires (bLink)',
          detail: 'Connexion lecture seule à tes comptes bancaires '
              'pour importer automatiquement tes transactions.',
          neverSent: 'Tes identifiants bancaires ne transitent jamais '
              'par nos serveurs. Seules les transactions sont importées.',
        ),
        const ConsentState(
          type: ConsentType.documentUpload,
          enabled: false,
          label: 'Documents uploadés',
          detail: 'Certificats LPP, relevés bancaires analysés par OCR '
              'pour pré-remplir tes données de prévoyance.',
          neverSent: 'Les documents originaux sont supprimes apres analyse. '
              'Seules les donnees extraites sont conservees localement.',
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
