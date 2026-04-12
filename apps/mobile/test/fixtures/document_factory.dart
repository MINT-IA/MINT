// document_factory.dart
//
// Deterministic test data generator for Swiss document types.
// Generates structured field maps matching the extraction schema.
// No real PDF/SVG generation — produces the DATA that would be extracted.
//
// Used by persona golden path tests (QA-09).

/// Factory for generating deterministic test document data.
///
/// Produces `Map<String, dynamic>` matching the extraction schema
/// for 4 Swiss document types: certificat_lpp, certificat_salaire,
/// attestation_3a, police_assurance.
class DocumentFactory {
  DocumentFactory._();

  /// Generate a LPP certificate (certificat de prevoyance).
  ///
  /// Returns structured field map matching LPP extraction schema.
  static Map<String, dynamic> lppCertificate({
    required String name,
    required double salary,
    required double lppCapital,
    required String canton,
    String caisse = 'Caisse de pension standard',
    double conversionRate = 6.8,
    double coordinationDeduction = 26460.0,
    int age = 40,
  }) {
    final salaireCoord = (salary - coordinationDeduction).clamp(3780.0, 88200.0);
    final bonificationRate = _lppBonificationRate(age);
    final annualContribution = salaireCoord * bonificationRate;

    return {
      'documentType': 'certificat_lpp',
      'extractedAt': DateTime.now().toIso8601String(),
      'fields': {
        'nom': name,
        'caissePension': caisse,
        'canton': canton,
        'salaireBrut': salary,
        'salaireAssure': salaireCoord,
        'deductionCoordination': coordinationDeduction,
        'avoirVieillesse': lppCapital,
        'tauxConversion': conversionRate,
        'bonificationAnnuelle': annualContribution,
        'tauxBonification': bonificationRate * 100,
        'rachatMaximal': _estimateRachatMax(age, salary, lppCapital),
        'prestation65': lppCapital + annualContribution * (65 - age),
        'renteAnnuelleEstimee': (lppCapital + annualContribution * (65 - age)) * conversionRate / 100,
      },
      'confidence': 0.92,
      'sourceType': 'certificate',
    };
  }

  /// Generate a salary certificate (certificat de salaire).
  ///
  /// Returns structured field map matching salary extraction schema.
  static Map<String, dynamic> salaryCertificate({
    required String name,
    required double salary,
    required String canton,
    String employer = 'Employer SA',
    int year = 2025,
    double? bonus,
    double socialChargesRate = 0.064,
  }) {
    final grossAnnual = salary + (bonus ?? 0);
    final socialCharges = grossAnnual * socialChargesRate;
    final lppContribution = _estimateLppContribution(salary);

    return {
      'documentType': 'certificat_salaire',
      'extractedAt': DateTime.now().toIso8601String(),
      'fields': {
        'nom': name,
        'employeur': employer,
        'canton': canton,
        'annee': year,
        'salaireBrut': grossAnnual,
        'salaireBase': salary,
        'bonus': bonus ?? 0,
        'chargesSociales': socialCharges,
        'cotisationAVS': grossAnnual * 0.053,
        'cotisationAC': grossAnnual * 0.011,
        'cotisationLPP': lppContribution,
        'salaireNet': grossAnnual - socialCharges - lppContribution,
        'fraisProfessionnels': 0,
        'voitureService': false,
      },
      'confidence': 0.95,
      'sourceType': 'certificate',
    };
  }

  /// Generate a 3a attestation (attestation pilier 3a).
  ///
  /// Returns structured field map matching 3a extraction schema.
  static Map<String, dynamic> attestation3a({
    required String name,
    required double capital,
    required String canton,
    String institution = 'Banque Cantonale',
    int year = 2025,
    double annualContribution = 7258.0,
    double returnRate = 1.5,
  }) {
    return {
      'documentType': 'attestation_3a',
      'extractedAt': DateTime.now().toIso8601String(),
      'fields': {
        'nom': name,
        'institution': institution,
        'canton': canton,
        'annee': year,
        'capitalAccumule': capital,
        'versementAnnuel': annualContribution,
        'plafondAnnuel': 7258.0,
        'tauxRendement': returnRate,
        'interetsAnnuels': capital * returnRate / 100,
        'deductionFiscale': annualContribution, // = versement (within plafond)
        'typeCompte': 'compte_3a',
        'beneficiaires': ['conjoint', 'enfants'],
      },
      'confidence': 0.93,
      'sourceType': 'certificate',
    };
  }

  /// Generate an insurance policy (police d'assurance).
  ///
  /// Returns structured field map matching insurance extraction schema.
  static Map<String, dynamic> insurancePolicy({
    required String name,
    required String canton,
    String type = 'vie_mixte',
    String assureur = 'Swiss Life SA',
    double primeAnnuelle = 3600.0,
    double capitalAssure = 100000.0,
    int duree = 20,
    double valeurRachat = 0.0,
  }) {
    return {
      'documentType': 'police_assurance',
      'extractedAt': DateTime.now().toIso8601String(),
      'fields': {
        'nom': name,
        'assureur': assureur,
        'canton': canton,
        'typeAssurance': type,
        'primeAnnuelle': primeAnnuelle,
        'capitalAssure': capitalAssure,
        'dureeAnsPrevue': duree,
        'valeurRachat': valeurRachat,
        'debutContrat': '${DateTime.now().year - 5}-01-01',
        'finContrat': '${DateTime.now().year - 5 + duree}-01-01',
        'beneficiaires': ['conjoint', 'enfants'],
        'estLie3a': type == 'vie_3a',
        'fraisGestion': primeAnnuelle * 0.08,
      },
      'confidence': 0.88,
      'sourceType': 'certificate',
    };
  }

  // ── Internal helpers ──────────────────────────────────────

  static double _lppBonificationRate(int age) {
    if (age < 25) return 0.0;
    if (age < 35) return 0.07;
    if (age < 45) return 0.10;
    if (age < 55) return 0.15;
    return 0.18;
  }

  static double _estimateRachatMax(int age, double salary, double currentCapital) {
    // Simplified: sum of future bonifications minus current capital
    double projected = 0;
    final salaireCoord = (salary - 26460).clamp(3780.0, 88200.0);
    for (int a = 25; a < 65; a++) {
      projected += salaireCoord * _lppBonificationRate(a);
    }
    return (projected - currentCapital).clamp(0, double.infinity);
  }

  static double _estimateLppContribution(double salary) {
    if (salary < 22680) return 0; // Below LPP threshold
    final salaireCoord = (salary - 26460).clamp(3780.0, 88200.0);
    return salaireCoord * 0.10; // Average employee share
  }
}
