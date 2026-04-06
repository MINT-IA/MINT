import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';

// ──────────────────────────────────────────────────────────
// Shared helper
// ──────────────────────────────────────────────────────────

/// Safely convert a dynamic JSON value to double.
double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

// ──────────────────────────────────────────────────────────
// Enum: Vault Document Type
// ──────────────────────────────────────────────────────────

/// Types of documents supported by the MINT vault.
enum VaultDocumentType {
  lppCertificate, // Certificat de prévoyance LPP
  salaryCertificate, // Certificat de salaire
  pillar3aAttestation, // Attestation 3e pilier
  insurancePolicy, // Police d'assurance (RC, ménage, vie, etc.)
  lease, // Bail / contrat de location
  lamalStatement, // Décompte LAMal / caisse maladie
  other, // Autre document
}

extension VaultDocumentTypeX on VaultDocumentType {
  String get apiValue {
    switch (this) {
      case VaultDocumentType.lppCertificate:
        return 'lpp_certificate';
      case VaultDocumentType.salaryCertificate:
        return 'salary_certificate';
      case VaultDocumentType.pillar3aAttestation:
        return 'pillar_3a_attestation';
      case VaultDocumentType.insurancePolicy:
        return 'insurance_policy';
      case VaultDocumentType.lease:
        return 'lease';
      case VaultDocumentType.lamalStatement:
        return 'lamal_statement';
      case VaultDocumentType.other:
        return 'other';
    }
  }

  static VaultDocumentType fromApi(String value) {
    switch (value) {
      case 'lpp_certificate':
        return VaultDocumentType.lppCertificate;
      case 'salary_certificate':
        return VaultDocumentType.salaryCertificate;
      case 'pillar_3a_attestation':
        return VaultDocumentType.pillar3aAttestation;
      case 'insurance_policy':
        return VaultDocumentType.insurancePolicy;
      case 'lease':
        return VaultDocumentType.lease;
      case 'lamal_statement':
        return VaultDocumentType.lamalStatement;
      default:
        return VaultDocumentType.other;
    }
  }
}

// ──────────────────────────────────────────────────────────
// Model: LPP Extracted Fields
// ──────────────────────────────────────────────────────────

/// Typed fields extracted from an LPP certificate by Docling.
class LppExtractedFields {
  final double? avoirObligatoire;
  final double? avoirSurobligatoire;
  final double? avoirVieillesseTotal;
  final double? salaireAssure;
  final double? salaireAvs;
  final double? deductionCoordination;
  final double? tauxConversionObligatoire;
  final double? tauxConversionSurobligatoire;
  final double? tauxConversionEnveloppe;
  final double? renteInvalidite;
  final double? capitalDeces;
  final double? renteConjoint;
  final double? renteEnfant;
  final double? rachatMaximum;
  final double? cotisationEmploye;
  final double? cotisationEmployeur;
  final double? remunerationRate;

  const LppExtractedFields({
    this.avoirObligatoire,
    this.avoirSurobligatoire,
    this.avoirVieillesseTotal,
    this.salaireAssure,
    this.salaireAvs,
    this.deductionCoordination,
    this.tauxConversionObligatoire,
    this.tauxConversionSurobligatoire,
    this.tauxConversionEnveloppe,
    this.renteInvalidite,
    this.capitalDeces,
    this.renteConjoint,
    this.renteEnfant,
    this.rachatMaximum,
    this.cotisationEmploye,
    this.cotisationEmployeur,
    this.remunerationRate,
  });

  factory LppExtractedFields.fromJson(Map<String, dynamic> json) {
    return LppExtractedFields(
      avoirObligatoire: _toDouble(json['avoir_obligatoire']),
      avoirSurobligatoire: _toDouble(json['avoir_surobligatoire']),
      avoirVieillesseTotal: _toDouble(json['avoir_vieillesse_total']),
      salaireAssure: _toDouble(json['salaire_assure']),
      salaireAvs: _toDouble(json['salaire_avs']),
      deductionCoordination: _toDouble(json['deduction_coordination']),
      tauxConversionObligatoire: _toDouble(json['taux_conversion_obligatoire']),
      tauxConversionSurobligatoire:
          _toDouble(json['taux_conversion_surobligatoire']),
      tauxConversionEnveloppe: _toDouble(json['taux_conversion_enveloppe']),
      renteInvalidite: _toDouble(json['rente_invalidite']),
      capitalDeces: _toDouble(json['capital_deces']),
      renteConjoint: _toDouble(json['rente_conjoint']),
      renteEnfant: _toDouble(json['rente_enfant']),
      rachatMaximum: _toDouble(json['rachat_maximum']),
      cotisationEmploye: _toDouble(json['cotisation_employe']),
      cotisationEmployeur: _toDouble(json['cotisation_employeur']),
      remunerationRate: _toDouble(json['remuneration_rate']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (avoirObligatoire != null) {
      map['avoir_obligatoire'] = avoirObligatoire;
    }
    if (avoirSurobligatoire != null) {
      map['avoir_surobligatoire'] = avoirSurobligatoire;
    }
    if (avoirVieillesseTotal != null) {
      map['avoir_vieillesse_total'] = avoirVieillesseTotal;
    }
    if (salaireAssure != null) map['salaire_assure'] = salaireAssure;
    if (salaireAvs != null) map['salaire_avs'] = salaireAvs;
    if (deductionCoordination != null) {
      map['deduction_coordination'] = deductionCoordination;
    }
    if (tauxConversionObligatoire != null) {
      map['taux_conversion_obligatoire'] = tauxConversionObligatoire;
    }
    if (tauxConversionSurobligatoire != null) {
      map['taux_conversion_surobligatoire'] = tauxConversionSurobligatoire;
    }
    if (tauxConversionEnveloppe != null) {
      map['taux_conversion_enveloppe'] = tauxConversionEnveloppe;
    }
    if (renteInvalidite != null) map['rente_invalidite'] = renteInvalidite;
    if (capitalDeces != null) map['capital_deces'] = capitalDeces;
    if (renteConjoint != null) map['rente_conjoint'] = renteConjoint;
    if (renteEnfant != null) map['rente_enfant'] = renteEnfant;
    if (rachatMaximum != null) map['rachat_maximum'] = rachatMaximum;
    if (cotisationEmploye != null) {
      map['cotisation_employe'] = cotisationEmploye;
    }
    if (cotisationEmployeur != null) {
      map['cotisation_employeur'] = cotisationEmployeur;
    }
    if (remunerationRate != null) {
      map['remuneration_rate'] = remunerationRate;
    }
    return map;
  }

  /// Number of non-null fields found.
  int get fieldsFound {
    int count = 0;
    if (avoirObligatoire != null) count++;
    if (avoirSurobligatoire != null) count++;
    if (avoirVieillesseTotal != null) count++;
    if (salaireAssure != null) count++;
    if (salaireAvs != null) count++;
    if (deductionCoordination != null) count++;
    if (tauxConversionObligatoire != null) count++;
    if (tauxConversionSurobligatoire != null) count++;
    if (tauxConversionEnveloppe != null) count++;
    if (renteInvalidite != null) count++;
    if (capitalDeces != null) count++;
    if (renteConjoint != null) count++;
    if (renteEnfant != null) count++;
    if (rachatMaximum != null) count++;
    if (cotisationEmploye != null) count++;
    if (cotisationEmployeur != null) count++;
    if (remunerationRate != null) count++;
    return count;
  }

  static const int fieldsTotal = 16;
}

// ──────────────────────────────────────────────────────────
// Model: Salary Extracted Fields
// ──────────────────────────────────────────────────────────

/// Fields extracted from a Swiss salary certificate (Lohnausweis).
class SalaryExtractedFields {
  final double? salaireBrut;
  final double? salaireNet;
  final double? cotisationAvs;
  final double? cotisationLpp;
  final double? cotisationAc;
  final double? cotisationLamal;
  final double? impotSource;
  final double? fraisProfessionnels;
  final double? allocationsEnfants;
  final String? employeur;
  final int? annee;

  const SalaryExtractedFields({
    this.salaireBrut,
    this.salaireNet,
    this.cotisationAvs,
    this.cotisationLpp,
    this.cotisationAc,
    this.cotisationLamal,
    this.impotSource,
    this.fraisProfessionnels,
    this.allocationsEnfants,
    this.employeur,
    this.annee,
  });

  factory SalaryExtractedFields.fromJson(Map<String, dynamic> json) {
    return SalaryExtractedFields(
      salaireBrut: _toDouble(json['salaire_brut']),
      salaireNet: _toDouble(json['salaire_net']),
      cotisationAvs: _toDouble(json['cotisation_avs']),
      cotisationLpp: _toDouble(json['cotisation_lpp']),
      cotisationAc: _toDouble(json['cotisation_ac']),
      cotisationLamal: _toDouble(json['cotisation_lamal']),
      impotSource: _toDouble(json['impot_source']),
      fraisProfessionnels: _toDouble(json['frais_professionnels']),
      allocationsEnfants: _toDouble(json['allocations_enfants']),
      employeur: json['employeur'] as String?,
      annee: json['annee'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (salaireBrut != null) map['salaire_brut'] = salaireBrut;
    if (salaireNet != null) map['salaire_net'] = salaireNet;
    if (cotisationAvs != null) map['cotisation_avs'] = cotisationAvs;
    if (cotisationLpp != null) map['cotisation_lpp'] = cotisationLpp;
    if (cotisationAc != null) map['cotisation_ac'] = cotisationAc;
    if (cotisationLamal != null) map['cotisation_lamal'] = cotisationLamal;
    if (impotSource != null) map['impot_source'] = impotSource;
    if (fraisProfessionnels != null) {
      map['frais_professionnels'] = fraisProfessionnels;
    }
    if (allocationsEnfants != null) {
      map['allocations_enfants'] = allocationsEnfants;
    }
    if (employeur != null) map['employeur'] = employeur;
    if (annee != null) map['annee'] = annee;
    return map;
  }

  /// Number of non-null fields found.
  int get fieldsFound {
    int count = 0;
    if (salaireBrut != null) count++;
    if (salaireNet != null) count++;
    if (cotisationAvs != null) count++;
    if (cotisationLpp != null) count++;
    if (cotisationAc != null) count++;
    if (cotisationLamal != null) count++;
    if (impotSource != null) count++;
    if (fraisProfessionnels != null) count++;
    if (allocationsEnfants != null) count++;
    if (employeur != null) count++;
    if (annee != null) count++;
    return count;
  }

  static const int fieldsTotal = 11;
}

// ──────────────────────────────────────────────────────────
// Model: Pillar 3a Extracted Fields
// ──────────────────────────────────────────────────────────

/// Fields extracted from a 3a attestation.
class Pillar3aExtractedFields {
  final double? montantVerse;
  final String? prestataire;
  final int? annee;
  final String? typeCompte; // "bank" or "insurance"

  const Pillar3aExtractedFields({
    this.montantVerse,
    this.prestataire,
    this.annee,
    this.typeCompte,
  });

  factory Pillar3aExtractedFields.fromJson(Map<String, dynamic> json) {
    return Pillar3aExtractedFields(
      montantVerse: _toDouble(json['montant_verse']),
      prestataire: json['prestataire'] as String?,
      annee: json['annee'] as int?,
      typeCompte: json['type_compte'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (montantVerse != null) map['montant_verse'] = montantVerse;
    if (prestataire != null) map['prestataire'] = prestataire;
    if (annee != null) map['annee'] = annee;
    if (typeCompte != null) map['type_compte'] = typeCompte;
    return map;
  }

  /// Number of non-null fields found.
  int get fieldsFound {
    int count = 0;
    if (montantVerse != null) count++;
    if (prestataire != null) count++;
    if (annee != null) count++;
    if (typeCompte != null) count++;
    return count;
  }

  static const int fieldsTotal = 4;
}

// ──────────────────────────────────────────────────────────
// Model: Insurance Extracted Fields
// ──────────────────────────────────────────────────────────

/// Fields extracted from an insurance policy.
class InsuranceExtractedFields {
  final String? assureur;
  final String? typeAssurance; // "RC", "menage", "vie", "maladie_complementaire"
  final double? primeAnnuelle;
  final double? franchise;
  final double? couverture;
  final String? dateDebut;
  final String? dateFin;
  final String? numeroPolice;

  const InsuranceExtractedFields({
    this.assureur,
    this.typeAssurance,
    this.primeAnnuelle,
    this.franchise,
    this.couverture,
    this.dateDebut,
    this.dateFin,
    this.numeroPolice,
  });

  factory InsuranceExtractedFields.fromJson(Map<String, dynamic> json) {
    return InsuranceExtractedFields(
      assureur: json['assureur'] as String?,
      typeAssurance: json['type_assurance'] as String?,
      primeAnnuelle: _toDouble(json['prime_annuelle']),
      franchise: _toDouble(json['franchise']),
      couverture: _toDouble(json['couverture']),
      dateDebut: json['date_debut'] as String?,
      dateFin: json['date_fin'] as String?,
      numeroPolice: json['numero_police'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (assureur != null) map['assureur'] = assureur;
    if (typeAssurance != null) map['type_assurance'] = typeAssurance;
    if (primeAnnuelle != null) map['prime_annuelle'] = primeAnnuelle;
    if (franchise != null) map['franchise'] = franchise;
    if (couverture != null) map['couverture'] = couverture;
    if (dateDebut != null) map['date_debut'] = dateDebut;
    if (dateFin != null) map['date_fin'] = dateFin;
    if (numeroPolice != null) map['numero_police'] = numeroPolice;
    return map;
  }

  /// Number of non-null fields found.
  int get fieldsFound {
    int count = 0;
    if (assureur != null) count++;
    if (typeAssurance != null) count++;
    if (primeAnnuelle != null) count++;
    if (franchise != null) count++;
    if (couverture != null) count++;
    if (dateDebut != null) count++;
    if (dateFin != null) count++;
    if (numeroPolice != null) count++;
    return count;
  }

  static const int fieldsTotal = 8;
}

// ──────────────────────────────────────────────────────────
// Model: Lease Extracted Fields
// ──────────────────────────────────────────────────────────

/// Fields extracted from a lease agreement (bail).
class LeaseExtractedFields {
  final double? loyerNet;
  final double? charges;
  final double? loyerBrut;
  final String? adresse;
  final String? regie;
  final int? preavisMois;
  final String? dateDebut;
  final String? prochaineEcheance;
  final double? tauxHypothecaireReference;

  const LeaseExtractedFields({
    this.loyerNet,
    this.charges,
    this.loyerBrut,
    this.adresse,
    this.regie,
    this.preavisMois,
    this.dateDebut,
    this.prochaineEcheance,
    this.tauxHypothecaireReference,
  });

  factory LeaseExtractedFields.fromJson(Map<String, dynamic> json) {
    return LeaseExtractedFields(
      loyerNet: _toDouble(json['loyer_net']),
      charges: _toDouble(json['charges']),
      loyerBrut: _toDouble(json['loyer_brut']),
      adresse: json['adresse'] as String?,
      regie: json['regie'] as String?,
      preavisMois: json['preavis_mois'] as int?,
      dateDebut: json['date_debut'] as String?,
      prochaineEcheance: json['prochaine_echeance'] as String?,
      tauxHypothecaireReference:
          _toDouble(json['taux_hypothecaire_reference']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (loyerNet != null) map['loyer_net'] = loyerNet;
    if (charges != null) map['charges'] = charges;
    if (loyerBrut != null) map['loyer_brut'] = loyerBrut;
    if (adresse != null) map['adresse'] = adresse;
    if (regie != null) map['regie'] = regie;
    if (preavisMois != null) map['preavis_mois'] = preavisMois;
    if (dateDebut != null) map['date_debut'] = dateDebut;
    if (prochaineEcheance != null) {
      map['prochaine_echeance'] = prochaineEcheance;
    }
    if (tauxHypothecaireReference != null) {
      map['taux_hypothecaire_reference'] = tauxHypothecaireReference;
    }
    return map;
  }

  /// Number of non-null fields found.
  int get fieldsFound {
    int count = 0;
    if (loyerNet != null) count++;
    if (charges != null) count++;
    if (loyerBrut != null) count++;
    if (adresse != null) count++;
    if (regie != null) count++;
    if (preavisMois != null) count++;
    if (dateDebut != null) count++;
    if (prochaineEcheance != null) count++;
    if (tauxHypothecaireReference != null) count++;
    return count;
  }

  static const int fieldsTotal = 9;
}

// ──────────────────────────────────────────────────────────
// Model: LAMal Extracted Fields
// ──────────────────────────────────────────────────────────

/// Fields extracted from a LAMal/health insurance statement.
class LamalExtractedFields {
  final String? caisse;
  final double? franchiseAnnuelle;
  final double? primesMensuelles;
  final double? fraisMedicaux;
  final double? participationAssuree;
  final double? remboursements;
  final int? annee;

  const LamalExtractedFields({
    this.caisse,
    this.franchiseAnnuelle,
    this.primesMensuelles,
    this.fraisMedicaux,
    this.participationAssuree,
    this.remboursements,
    this.annee,
  });

  factory LamalExtractedFields.fromJson(Map<String, dynamic> json) {
    return LamalExtractedFields(
      caisse: json['caisse'] as String?,
      franchiseAnnuelle: _toDouble(json['franchise_annuelle']),
      primesMensuelles: _toDouble(json['primes_mensuelles']),
      fraisMedicaux: _toDouble(json['frais_medicaux']),
      participationAssuree: _toDouble(json['participation_assuree']),
      remboursements: _toDouble(json['remboursements']),
      annee: json['annee'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (caisse != null) map['caisse'] = caisse;
    if (franchiseAnnuelle != null) {
      map['franchise_annuelle'] = franchiseAnnuelle;
    }
    if (primesMensuelles != null) map['primes_mensuelles'] = primesMensuelles;
    if (fraisMedicaux != null) map['frais_medicaux'] = fraisMedicaux;
    if (participationAssuree != null) {
      map['participation_assuree'] = participationAssuree;
    }
    if (remboursements != null) map['remboursements'] = remboursements;
    if (annee != null) map['annee'] = annee;
    return map;
  }

  /// Number of non-null fields found.
  int get fieldsFound {
    int count = 0;
    if (caisse != null) count++;
    if (franchiseAnnuelle != null) count++;
    if (primesMensuelles != null) count++;
    if (fraisMedicaux != null) count++;
    if (participationAssuree != null) count++;
    if (remboursements != null) count++;
    if (annee != null) count++;
    return count;
  }

  static const int fieldsTotal = 7;
}

// ──────────────────────────────────────────────────────────
// Model: Vault Extracted Fields (generic wrapper)
// ──────────────────────────────────────────────────────────

/// Generic container for extracted fields from any document type.
class VaultExtractedFields {
  final VaultDocumentType documentType;
  final LppExtractedFields? lpp;
  final SalaryExtractedFields? salary;
  final Pillar3aExtractedFields? pillar3a;
  final InsuranceExtractedFields? insurance;
  final LeaseExtractedFields? lease;
  final LamalExtractedFields? lamal;

  const VaultExtractedFields({
    required this.documentType,
    this.lpp,
    this.salary,
    this.pillar3a,
    this.insurance,
    this.lease,
    this.lamal,
  });

  factory VaultExtractedFields.fromJson(
      Map<String, dynamic> json, VaultDocumentType type) {
    switch (type) {
      case VaultDocumentType.lppCertificate:
        return VaultExtractedFields(
          documentType: type,
          lpp: LppExtractedFields.fromJson(json),
        );
      case VaultDocumentType.salaryCertificate:
        return VaultExtractedFields(
          documentType: type,
          salary: SalaryExtractedFields.fromJson(json),
        );
      case VaultDocumentType.pillar3aAttestation:
        return VaultExtractedFields(
          documentType: type,
          pillar3a: Pillar3aExtractedFields.fromJson(json),
        );
      case VaultDocumentType.insurancePolicy:
        return VaultExtractedFields(
          documentType: type,
          insurance: InsuranceExtractedFields.fromJson(json),
        );
      case VaultDocumentType.lease:
        return VaultExtractedFields(
          documentType: type,
          lease: LeaseExtractedFields.fromJson(json),
        );
      case VaultDocumentType.lamalStatement:
        return VaultExtractedFields(
          documentType: type,
          lamal: LamalExtractedFields.fromJson(json),
        );
      case VaultDocumentType.other:
        return VaultExtractedFields(documentType: type);
    }
  }

  int get fieldsFound {
    return lpp?.fieldsFound ??
        salary?.fieldsFound ??
        pillar3a?.fieldsFound ??
        insurance?.fieldsFound ??
        lease?.fieldsFound ??
        lamal?.fieldsFound ??
        0;
  }

  int get fieldsTotal {
    return lpp != null
        ? LppExtractedFields.fieldsTotal
        : salary != null
            ? SalaryExtractedFields.fieldsTotal
            : pillar3a != null
                ? Pillar3aExtractedFields.fieldsTotal
                : insurance != null
                    ? InsuranceExtractedFields.fieldsTotal
                    : lease != null
                        ? LeaseExtractedFields.fieldsTotal
                        : lamal != null
                            ? LamalExtractedFields.fieldsTotal
                            : 0;
  }
}

// ──────────────────────────────────────────────────────────
// Model: Document Upload Result
// ──────────────────────────────────────────────────────────

/// Result returned after uploading and processing a document.
class DocumentUploadResult {
  final String id;
  final VaultDocumentType documentType;
  final VaultExtractedFields extractedFields;
  final double confidence;
  final int fieldsFound;
  final int fieldsTotal;
  final List<String> warnings;

  const DocumentUploadResult({
    required this.id,
    required this.documentType,
    required this.extractedFields,
    required this.confidence,
    required this.fieldsFound,
    required this.fieldsTotal,
    this.warnings = const [],
  });

  factory DocumentUploadResult.fromJson(Map<String, dynamic> json) {
    final extractedMap =
        json['extracted_fields'] as Map<String, dynamic>? ?? {};
    // Parse document type first, default to LPP for backward compatibility
    final rawType = json['document_type'] as String? ?? 'lpp_certificate';
    final docType = VaultDocumentTypeX.fromApi(rawType);
    return DocumentUploadResult(
      id: json['id'] as String? ?? '',
      documentType: docType,
      extractedFields: VaultExtractedFields.fromJson(extractedMap, docType),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      fieldsFound: json['fields_found'] as int? ?? 0,
      fieldsTotal: json['fields_total'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Model: Document Summary
// ──────────────────────────────────────────────────────────

/// Summary of a previously uploaded document.
class DocumentSummary {
  final String id;
  final VaultDocumentType documentType;
  final DateTime uploadDate;
  final double confidence;
  final int fieldsFound;

  const DocumentSummary({
    required this.id,
    required this.documentType,
    required this.uploadDate,
    required this.confidence,
    required this.fieldsFound,
  });

  factory DocumentSummary.fromJson(Map<String, dynamic> json) {
    return DocumentSummary(
      id: json['id'] as String? ?? '',
      documentType: VaultDocumentTypeX.fromApi(
          json['document_type'] as String? ?? 'other'),
      uploadDate: DateTime.tryParse(json['upload_date'] as String? ?? '') ??
          DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      fieldsFound: json['fields_found'] as int? ?? 0,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Model: Bank Transaction
// ──────────────────────────────────────────────────────────

/// A single transaction extracted from a bank statement.
class BankTransaction {
  final DateTime date;
  final String description;
  final double amount;
  final double? balance;
  final String category;
  final String? subcategory;
  final bool isRecurring;

  const BankTransaction({
    required this.date,
    required this.description,
    required this.amount,
    this.balance,
    required this.category,
    this.subcategory,
    this.isRecurring = false,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    return BankTransaction(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble(),
      category: json['category'] as String? ?? 'Divers',
      subcategory: json['subcategory'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'description': description,
      'amount': amount,
      if (balance != null) 'balance': balance,
      'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      'is_recurring': isRecurring,
    };
  }
}

// ──────────────────────────────────────────────────────────
// Model: Bank Statement Result
// ──────────────────────────────────────────────────────────

/// Result returned after uploading and processing a bank statement.
class BankStatementResult {
  final String bankName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String currency;
  final List<BankTransaction> transactions;
  final double totalCredits;
  final double totalDebits;
  final double confidence;
  final List<String> warnings;
  final Map<String, double> categorySummary;
  final List<BankTransaction> recurringMonthly;

  const BankStatementResult({
    required this.bankName,
    required this.periodStart,
    required this.periodEnd,
    this.currency = 'CHF',
    required this.transactions,
    required this.totalCredits,
    required this.totalDebits,
    required this.confidence,
    this.warnings = const [],
    this.categorySummary = const {},
    this.recurringMonthly = const [],
  });

  factory BankStatementResult.fromJson(Map<String, dynamic> json) {
    final txList = (json['transactions'] as List<dynamic>?)
            ?.map((t) => BankTransaction.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];
    final recurringList = (json['recurring_monthly'] as List<dynamic>?)
            ?.map((t) => BankTransaction.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];
    final catSummary = <String, double>{};
    final rawCat = json['category_summary'] as Map<String, dynamic>?;
    if (rawCat != null) {
      for (final entry in rawCat.entries) {
        catSummary[entry.key] = (entry.value as num).toDouble();
      }
    }

    return BankStatementResult(
      bankName: json['bank_name'] as String? ?? 'Banque inconnue',
      periodStart:
          DateTime.tryParse(json['period_start'] as String? ?? '') ??
              DateTime.now(),
      periodEnd:
          DateTime.tryParse(json['period_end'] as String? ?? '') ??
              DateTime.now(),
      currency: json['currency'] as String? ?? 'CHF',
      transactions: txList,
      totalCredits: (json['total_credits'] as num?)?.toDouble() ?? 0.0,
      totalDebits: (json['total_debits'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
      categorySummary: catSummary,
      recurringMonthly: recurringList,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Model: Budget Import Preview
// ──────────────────────────────────────────────────────────

/// Preview of budget data derived from a bank statement analysis.
class BudgetImportPreview {
  final double estimatedMonthlyIncome;
  final double estimatedMonthlyExpenses;
  final List<MapEntry<String, double>> topCategories;
  final List<BankTransaction> recurringCharges;
  final double savingsRate;

  const BudgetImportPreview({
    required this.estimatedMonthlyIncome,
    required this.estimatedMonthlyExpenses,
    required this.topCategories,
    required this.recurringCharges,
    required this.savingsRate,
  });

  /// Derive a budget import preview from a [BankStatementResult].
  factory BudgetImportPreview.fromStatementResult(BankStatementResult result) {
    final income = result.totalCredits;
    final expenses = result.totalDebits.abs();
    final savings = income > 0 ? ((income - expenses) / income) * 100 : 0.0;

    final sortedCategories = result.categorySummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BudgetImportPreview(
      estimatedMonthlyIncome: income,
      estimatedMonthlyExpenses: expenses,
      topCategories: sortedCategories,
      recurringCharges: result.recurringMonthly,
      savingsRate: savings,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Document Service
// ──────────────────────────────────────────────────────────

/// Service for uploading and managing user documents (LPP certificates, etc.).
///
/// Uses the backend POST /api/v1/documents/upload (multipart),
/// GET /api/v1/documents/, and DELETE /api/v1/documents/{id}.
/// Documents are analyzed via Docling on the backend.
class DocumentService {
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;
  DocumentService._internal();

  static String get _baseUrl => ApiService.baseUrl;

  /// Maximum file size for PDF uploads (20 MB).
  static const int maxPdfSizeBytes = 20 * 1024 * 1024;

  /// Maximum file size for bank statement uploads (10 MB).
  static const int maxStatementSizeBytes = 10 * 1024 * 1024;

  /// Upload a PDF document for analysis.
  ///
  /// [type] specifies the kind of document being uploaded. Defaults to
  /// [VaultDocumentType.lppCertificate] for backward compatibility.
  /// Returns a [DocumentUploadResult] with extracted fields and confidence.
  Future<DocumentUploadResult> uploadDocument(
    File file, {
    VaultDocumentType type = VaultDocumentType.lppCertificate,
  }) async {
    // Client-side file size validation
    final fileSize = await file.length();
    if (fileSize > maxPdfSizeBytes) {
      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      throw DocumentServiceException(
        code: 'file_too_large',
        // Dynamic interpolation — not extracted
        message: 'Le fichier ($sizeMb Mo) depasse la limite de 20 Mo.',
      );
    }

    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/upload');

    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['document_type'] = type.apiValue;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DocumentUploadResult.fromJson(json);
    } else {
      final detail = _tryDecodeError(response.body);
      throw DocumentServiceException(
        code: 'upload_failed',
        message: detail ?? 'Upload failed (${response.statusCode}).',
      );
    }
  }

  /// Upload a bank statement (CSV or PDF) for transaction analysis.
  ///
  /// Returns a [BankStatementResult] with extracted transactions and summaries.
  Future<BankStatementResult> uploadBankStatement(File file) async {
    // Client-side file size validation
    final fileSize = await file.length();
    if (fileSize > maxStatementSizeBytes) {
      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      throw DocumentServiceException(
        code: 'file_too_large',
        // Dynamic interpolation — not extracted
        message: 'Le fichier ($sizeMb Mo) depasse la limite de 10 Mo.',
      );
    }

    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/upload-statement');

    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return BankStatementResult.fromJson(json);
    } else {
      final detail = _tryDecodeError(response.body);
      throw DocumentServiceException(
        code: 'statement_upload_failed',
        message: detail ?? 'Bank statement upload failed (${response.statusCode}).',
      );
    }
  }

  /// List all documents uploaded by the current user.
  Future<List<DocumentSummary>> listDocuments() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      // Handle both wrapped {"documents": [...]} and bare [...] responses
      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded.containsKey('documents')) {
        list = decoded['documents'] as List<dynamic>;
      } else {
        list = [];
      }
      return list
          .map((item) =>
              DocumentSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw DocumentServiceException(
        code: 'list_failed',
        message: 'Failed to load documents (${response.statusCode}).',
      );
    }
  }

  /// Delete a document by its ID.
  Future<bool> deleteDocument(String id) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/$id');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .delete(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      throw DocumentServiceException(
        code: 'delete_failed',
        message: 'Failed to delete document (${response.statusCode}).',
      );
    }
  }

  String? _tryDecodeError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String? ?? json['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  SCAN SYNC + CLAUDE VISION
  // ══════════════════════════════════════════════════════════

  /// Sync confirmed scan extraction to backend.
  /// Called after user reviews and confirms extracted fields.
  /// Offline-first: failure is logged but never blocks the UX.
  static Future<Map<String, dynamic>?> sendScanConfirmation({
    required String documentType,
    required List<Map<String, dynamic>> confirmedFields,
    required double overallConfidence,
    String extractionMethod = 'claude_vision',
  }) async {
    try {
      final baseUrl = ApiService.baseUrl;
      final token = await AuthService.getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/documents/scan-confirmation'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'documentType': documentType,
          'confirmedFields': confirmedFields,
          'overallConfidence': overallConfidence,
          'extractionMethod': extractionMethod,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      // Offline-first: sync failure is not user-facing.
      return null;
    }
  }

  /// Extract document data using Claude Vision (backend).
  /// Replaces MLKit OCR — better accuracy for Swiss financial docs.
  /// Returns structured fields or null on failure.
  static Future<Map<String, dynamic>?> extractWithVision({
    required String imageBase64,
    required String documentType,
    String? canton,
    String? languageHint,
  }) async {
    try {
      final baseUrl = ApiService.baseUrl;
      final token = await AuthService.getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/documents/extract-vision'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'documentType': documentType,
          'imageBase64': imageBase64,
          if (canton != null) 'canton': canton,
          if (languageHint != null) 'languageHint': languageHint,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 422) {
        throw const DocumentServiceException(
          code: 'not_financial',
          message: 'Document classified as non-financial',
        );
      }
      return null;
    } catch (e) {
      if (e is DocumentServiceException) rethrow;
      return null;
    }
  }
  /// Fetch premier eclairage (4-layer insight) for extracted document data.
  /// Returns parsed JSON response or null on failure.
  static Future<Map<String, dynamic>?> fetchPremierEclairage({
    required String documentType,
    required List<Map<String, dynamic>> extractedFields,
    required double overallConfidence,
    String? planType,
    String? planTypeWarning,
    String? canton,
  }) async {
    try {
      final baseUrl = ApiService.baseUrl;
      final token = await AuthService.getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/documents/premier-eclairage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'documentType': documentType,
          'extractedFields': extractedFields,
          'overallConfidence': overallConfidence,
          if (planType != null) 'planType': planType,
          if (planTypeWarning != null) 'planTypeWarning': planTypeWarning,
          if (canton != null) 'canton': canton,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Custom exception for DocumentService errors.
class DocumentServiceException implements Exception {
  final String code;
  final String message;

  const DocumentServiceException({required this.code, required this.message});

  @override
  String toString() => 'DocumentServiceException($code): $message';
}
