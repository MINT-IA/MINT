import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Service de tracking des conversions d'affiliation
class AffiliateService {
  static const _uuid = Uuid();

  // Codes partenaires (à obtenir lors de la signature des contrats)
  static const String _viacPartnerCode =
      'MINT_PARTNER'; // Remplacer par le vrai code
  static const String _finpensionPartnerCode =
      'mint'; // Remplacer par le vrai code
  static const String _franklyPartnerCode =
      'mint'; // Remplacer par le vrai code

  /// Génère un lien d'affiliation tracké unique
  static String generateTrackedLink({
    required String provider,
    String? userId,
  }) {
    final trackingId = userId ?? _uuid.v4();

    switch (provider.toLowerCase()) {
      case 'viac':
        return 'https://viac.ch/fr?ref=$_viacPartnerCode&utm_source=mint&utm_medium=app&utm_campaign=3a_optimization&tracking_id=$trackingId';

      case 'finpension':
        return 'https://finpension.ch/fr/?partner=$_finpensionPartnerCode&utm_source=mint&utm_medium=app&utm_campaign=3a_optimization&tracking_id=$trackingId';

      case 'frankly':
        return 'https://www.frankly.ch/fr/3a/?partner=$_franklyPartnerCode&utm_source=mint&utm_medium=app&utm_campaign=3a_optimization&tracking_id=$trackingId';

      default:
        return '';
    }
  }

  /// Log un clic sur un lien d'affiliation (pour analytics)
  static Future<void> logAffiliateClick({
    required String provider,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Envoyer à un service analytics (Firebase, Amplitude, etc.)
    if (kDebugMode) {
      debugPrint('[AFFILIATE] Click: $provider');
    }

    // Exemple d'implémentation future :
    // await AnalyticsService.logEvent(
    //   'affiliate_click',
    //   parameters: {
    //     'provider': provider,
    //     'user_id': userId,
    //     'timestamp': DateTime.now().toIso8601String(),
    //     ...?metadata,
    //   },
    // );
  }

  /// Log une conversion confirmée (appelé manuellement ou via webhook partenaire)
  static Future<void> logConversion({
    required String provider,
    required String userId,
    required double commission,
  }) async {
    // TODO: Enregistrer dans la base de données
    if (kDebugMode) {
      debugPrint('[AFFILIATE] Conversion: $provider');
    }

    // Exemple d'implémentation future :
    // await DatabaseService.recordConversion(
    //   userId: userId,
    //   provider: provider,
    //   commission: commission,
    //   timestamp: DateTime.now(),
    // );
  }

  /// Récupère les statistiques de conversion
  static Future<Map<String, dynamic>> getConversionStats() async {
    // TODO: Récupérer depuis la DB
    return {
      'total_clicks': 0,
      'total_conversions': 0,
      'conversion_rate': 0.0,
      'total_commission': 0.0,
      'by_provider': {
        'viac': {'clicks': 0, 'conversions': 0, 'commission': 0.0},
        'finpension': {'clicks': 0, 'conversions': 0, 'commission': 0.0},
      },
    };
  }

  /// Informations sur les commissions par provider
  static Map<String, CommissionInfo> get providerCommissions => {
        'viac': CommissionInfo(
          provider: 'VIAC',
          amount: 120.0,
          type: CommissionType.oneTime,
          description: 'Commission unique à l\'ouverture du compte',
        ),
        'finpension': CommissionInfo(
          provider: 'Finpension',
          amount: 100.0,
          type: CommissionType.oneTime,
          description: 'Commission unique à l\'ouverture du compte',
        ),
        'frankly': CommissionInfo(
          provider: 'frankly',
          amount: 80.0,
          type: CommissionType.oneTime,
          description: 'Commission unique à l\'ouverture du compte',
        ),
      };
}

/// Informations sur une commission d'affiliation
class CommissionInfo {
  final String provider;
  final double amount;
  final CommissionType type;
  final String description;

  const CommissionInfo({
    required this.provider,
    required this.amount,
    required this.type,
    required this.description,
  });
}

enum CommissionType {
  oneTime,
  recurring,
}
