/// Service de confidentialite -- nLPD (Loi sur la protection des donnees)
/// Gere l'export, la suppression et le consentement des donnees utilisateur.
class PrivacyService {
  PrivacyService._();

  /// Categories de traitement des donnees.
  /// F3-4: Includes ALL 7 ConsentType values so the consent dashboard
  /// displays every consent toggle to the user.
  static const List<Map<String, dynamic>> dataCategories = [
    {
      'id': 'core_profile',
      'label': 'Profil de base',
      'description':
          'Donnees necessaires au fonctionnement de l\'app (age, canton, revenu).',
      'legalBasis': 'Execution du contrat (nLPD art. 31 al. 1)',
      'required': true,
      'retentionDays': 365,
    },
    {
      'id': 'byok_data_sharing',
      'label': 'Personnalisation IA',
      'description':
          'Envoi de donnees financieres agregees a ton fournisseur IA '
          'pour personnaliser les textes du coach.',
      'legalBasis': 'Consentement (nLPD art. 6 al. 6)',
      'required': false,
      'retentionDays': 30,
    },
    {
      'id': 'snapshot_storage',
      'label': 'Historique de progression',
      'description':
          'Conservation de l\'historique de tes projections pour suivre '
          'ta progression dans le temps.',
      'legalBasis': 'Consentement (nLPD art. 6 al. 6)',
      'required': false,
      'retentionDays': 365,
    },
    {
      'id': 'analytics',
      'label': 'Analyse d\'utilisation',
      'description': 'Statistiques anonymisees pour ameliorer l\'app.',
      'legalBasis': 'Consentement (nLPD art. 6 al. 6)',
      'required': false,
      'retentionDays': 90,
    },
    {
      'id': 'coaching_notifications',
      'label': 'Notifications proactives',
      'description':
          'Alertes et rappels personnalises (ex: echeance 3a).',
      'legalBasis': 'Consentement (nLPD art. 6 al. 6)',
      'required': false,
      'retentionDays': 180,
    },
    {
      'id': 'open_banking',
      'label': 'Donnees bancaires (bLink)',
      'description': 'Connexion lecture seule a tes comptes bancaires.',
      'legalBasis': 'Consentement explicite (nLPD art. 6 al. 7)',
      'required': false,
      'retentionDays': 30,
    },
    {
      'id': 'document_upload',
      'label': 'Documents uploades',
      'description':
          'Certificats LPP, releves bancaires analyses par Docling.',
      'legalBasis': 'Consentement (nLPD art. 6 al. 6)',
      'required': false,
      'retentionDays': 365,
    },
    {
      'id': 'rag_queries',
      'label': 'Questions a l\'assistant',
      'description':
          'Historique des questions posees (BYOK -- ta propre cle API).',
      'legalBasis': 'Consentement (nLPD art. 6 al. 6)',
      'required': false,
      'retentionDays': 30,
    },
  ];

  /// Generate a data export summary (local mock -- real export via backend API)
  static Map<String, dynamic> generateExportSummary({
    required String profileId,
    required Map<String, dynamic> profileData,
  }) {
    final categories = <String>{};
    if (profileData['birthYear'] != null) categories.add('core_profile');
    if (profileData['canton'] != null) categories.add('core_profile');
    if (profileData['income'] != null) categories.add('core_profile');
    if (profileData['analyticsEnabled'] == true) categories.add('analytics');
    if (profileData['coachingEnabled'] == true) {
      categories.add('coaching_notifications');
    }
    if (profileData['openBankingConnected'] == true) {
      categories.add('open_banking');
    }
    if (profileData['documentsUploaded'] == true) {
      categories.add('document_upload');
    }
    if (profileData['ragQueriesUsed'] == true) categories.add('rag_queries');

    return {
      'profileId': profileId,
      'exportDate': DateTime.now().toIso8601String(),
      'format': 'JSON',
      'dataCategories': categories.toList(),
      'retentionPolicy':
          'Les donnees sont conservees selon les durees indiquees par categorie. '
              'Tu peux demander la suppression a tout moment.',
      'disclaimer':
          'Export de donnees conformement a la nLPD (art. 25). '
              'Ne constitue pas un document juridique officiel.',
      'sources': [
        'nLPD art. 25 (droit d\'acces)',
        'nLPD art. 28 (portabilite)',
      ],
    };
  }

  /// Get consent status for all categories
  static List<Map<String, dynamic>> getConsentStatus({
    Map<String, bool>? currentConsents,
  }) {
    return dataCategories.map((cat) {
      final id = cat['id'] as String;
      final isRequired = cat['required'] as bool;
      return {
        ...cat,
        'consented': isRequired ? true : (currentConsents?[id] ?? false),
        'canRevoke': !isRequired,
      };
    }).toList();
  }

  /// Validate that a consent map contains all required categories
  static bool validateRequiredConsents(Map<String, bool> consents) {
    for (final cat in dataCategories) {
      final isRequired = cat['required'] as bool;
      if (isRequired) {
        final id = cat['id'] as String;
        if (consents[id] != true) return false;
      }
    }
    return true;
  }

  /// Get category details by ID
  static Map<String, dynamic>? getCategoryById(String categoryId) {
    try {
      return dataCategories.firstWhere(
        (cat) => cat['id'] == categoryId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get only optional (revocable) categories
  static List<Map<String, dynamic>> get optionalCategories {
    return dataCategories
        .where((cat) => cat['required'] == false)
        .toList();
  }

  /// Get only required categories
  static List<Map<String, dynamic>> get requiredCategories {
    return dataCategories
        .where((cat) => cat['required'] == true)
        .toList();
  }

  /// Get retention days for a specific category
  static int? getRetentionDays(String categoryId) {
    final cat = getCategoryById(categoryId);
    return cat?['retentionDays'] as int?;
  }

  /// Disclaimer nLPD
  static const String disclaimer =
      'MINT respecte la nLPD (Loi federale sur la protection des donnees, '
      'entree en vigueur le 1er septembre 2023). '
      'Tes donnees personnelles ne sont jamais vendues ni partagees '
      'avec des tiers sans ton consentement explicite. '
      'Tu peux a tout moment exporter ou supprimer tes donnees.';

  /// Sources legales
  static const List<String> sources = [
    'nLPD (RS 235.1) -- Loi federale sur la protection des donnees',
    'nLPD art. 6 -- Principes (consentement)',
    'nLPD art. 19 -- Devoir d\'informer',
    'nLPD art. 25 -- Droit d\'acces',
    'nLPD art. 28 -- Droit a la remise ou a la transmission des donnees (portabilite)',
    'nLPD art. 32 -- Droit de demander l\'effacement',
    'OPDo (RS 235.11) -- Ordonnance sur la protection des donnees',
  ];
}
