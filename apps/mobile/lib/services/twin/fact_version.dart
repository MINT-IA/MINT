// L'enveloppe d'une version de fait — le jumeau financier.
//
// POURQUOI
//
// Un fait financier écrasé par le suivant ne raconte rien. « Intérêts
// hypothécaires : CHF 4'250 » ne suffit pas : il faut savoir de quelle année
// fiscale il s'agit, d'où le chiffre vient, quand il a été obtenu, s'il est
// confirmé ou estimé, combien de temps il reste probablement valable, ce qu'il
// remplace, et si la personne en a autorisé l'usage. C'est cette différence
// qui sépare une photo d'un jumeau.
//
// Écrire un fait AJOUTE donc une version et référence celle qu'elle remplace.
// Le magasin plat clé-valeur existant reste, mais change de rôle : il devient
// la PROJECTION de l'état courant, plus l'autorité.
//
// Deux formes plus ambitieuses ont été écartées pour disproportion — le
// bitemporel complet et le journal d'événements métier intégral. Elles
// apporteraient la correction rétroactive, dont aucun besoin réel n'est encore
// constaté.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

/// D'où vient la donnée. La provenance conditionne la confiance qu'on peut
/// lui accorder et ce qu'on a le droit d'en faire.
enum FactSource {
  /// La personne l'a saisie elle-même.
  userDeclaration,

  /// Extraite d'un document qu'elle a fourni — et confirmée par elle avant de
  /// devenir canonique.
  document,

  /// Reçue d'une institution, avec consentement explicite et révocable.
  connection,

  /// Enveloppée depuis le magasin plat lors de la migration : la valeur est
  /// réelle, mais son contexte d'origine est perdu.
  migratedV1,
}

/// Confirmé par la personne, ou estimé par MINT. Un chiffre estimé ne doit
/// jamais être présenté comme un chiffre su.
enum FactStatus { confirmed, estimated }

/// Une version immuable d'un fait.
///
/// `factId` identifie le fait à travers le temps ; `versionId` identifie CETTE
/// version. Deux versions du même `factId` racontent une évolution — un
/// déménagement, une augmentation, un mariage.
class FactVersion {
  const FactVersion({
    required this.factId,
    required this.versionId,
    required this.factType,
    required this.payload,
    required this.assertedAt,
    required this.recordedAt,
    required this.source,
    required this.status,
    required this.schemaVersion,
    this.effectiveFrom,
    this.effectiveTo,
    this.fiscalYear,
    this.validUntil,
    this.needsConfirmation = false,
    this.supersedesVersionId,
    this.consentRef,
  });

  /// Identité du fait, stable dans le temps.
  final String factId;

  /// Identité de cette version-ci.
  final String versionId;

  /// Ce dont il s'agit : `domicile`, `housing`, `revenu`…
  final String factType;

  /// Les valeurs. Scalaires uniquement : une version doit rester lisible et
  /// comparable, pas porter une structure arbitraire.
  final Map<String, Object?> payload;

  /// Depuis quand c'est vrai — PAS la date de saisie.
  ///
  /// Null tant que MINT ne l'a pas demandé. Null se lit « on ne sait pas », et
  /// une date d'effet inconnue interdit toute réponse rétroactive. C'est une
  /// dégradation explicite, préférable à une date fabriquée.
  final DateTime? effectiveFrom;

  final DateTime? effectiveTo;

  /// Année fiscale à laquelle la valeur se rapporte, quand la question a un
  /// sens (intérêts hypothécaires, versements 3a).
  final int? fiscalYear;

  /// Quand la personne l'a déclaré.
  final DateTime assertedAt;

  /// Quand MINT l'a écrit. Distinct de `assertedAt` : une déclaration de
  /// janvier peut être enregistrée en mars.
  final DateTime recordedAt;

  final FactSource source;
  final FactStatus status;

  /// Au-delà, la valeur est probablement périmée. MINT peut alors le dire —
  /// et non recalculer en silence sur une donnée morte.
  final DateTime? validUntil;

  final bool needsConfirmation;

  /// La version que celle-ci remplace. Null pour la première.
  final String? supersedesVersionId;

  final int schemaVersion;

  /// Le consentement qui autorise l'usage de cette donnée.
  ///
  /// Référence seulement : le modèle de consentement n'existe pas encore. Tant
  /// qu'il n'existe pas, ce champ est un vœu, et l'ADR le dit.
  final String? consentRef;

  bool get isCurrent => effectiveTo == null;

  /// Cette version peut-elle parler de cette année fiscale ?
  ///
  /// Sans date d'effet, la seule réponse honnête part de l'année de la
  /// déclaration : quelqu'un ayant déménagé n'habitait pas forcément là
  /// l'an dernier.
  bool coversFiscalYear(int year) {
    if (fiscalYear != null) return fiscalYear == year;
    final from = effectiveFrom ?? assertedAt;
    if (year < from.toUtc().year) return false;
    final to = effectiveTo;
    return to == null || year <= to.toUtc().year;
  }

  /// Périmée à cette date ?
  bool isStaleAt(DateTime moment) {
    final limit = validUntil;
    return limit != null && moment.toUtc().isAfter(limit.toUtc());
  }

  FactVersion supersededBy(String nextVersionId, DateTime at) => FactVersion(
        factId: factId,
        versionId: versionId,
        factType: factType,
        payload: payload,
        effectiveFrom: effectiveFrom,
        effectiveTo: at.toUtc(),
        fiscalYear: fiscalYear,
        assertedAt: assertedAt,
        recordedAt: recordedAt,
        source: source,
        status: status,
        validUntil: validUntil,
        needsConfirmation: needsConfirmation,
        supersedesVersionId: supersedesVersionId,
        schemaVersion: schemaVersion,
        consentRef: consentRef,
      );

  Map<String, Object?> toJson() => {
        'factId': factId,
        'versionId': versionId,
        'factType': factType,
        'payload': payload,
        'effectiveFrom': effectiveFrom?.toUtc().toIso8601String(),
        'effectiveTo': effectiveTo?.toUtc().toIso8601String(),
        'fiscalYear': fiscalYear,
        'assertedAt': assertedAt.toUtc().toIso8601String(),
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'source': source.name,
        'status': status.name,
        'validUntil': validUntil?.toUtc().toIso8601String(),
        'needsConfirmation': needsConfirmation,
        'supersedesVersionId': supersedesVersionId,
        'schemaVersion': schemaVersion,
        'consentRef': consentRef,
      };

  /// Lecture STRICTE : une version illisible est une corruption, pas une
  /// version à sauter. La sauter amputerait l'historique en silence.
  static FactVersion fromJson(Map<String, Object?> json) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('champ « $key » absent ou vide', json.toString());  // lint-ignore
      }
      return value;
    }

    DateTime requiredDate(String key) {
      final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
      if (parsed == null) {
        throw FormatException('date « $key » illisible', json.toString());  // lint-ignore
      }
      return parsed.toUtc();
    }

    DateTime? optionalDate(String key) {
      final raw = json[key];
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed == null) {
        throw FormatException('date « $key » illisible', json.toString());  // lint-ignore
      }
      return parsed.toUtc();
    }

    final payload = json['payload'];
    if (payload is! Map) {
      throw FormatException('payload absent', json.toString());  // lint-ignore
    }

    return FactVersion(
      factId: required('factId'),
      versionId: required('versionId'),
      factType: required('factType'),
      payload: Map<String, Object?>.from(payload),
      effectiveFrom: optionalDate('effectiveFrom'),
      effectiveTo: optionalDate('effectiveTo'),
      fiscalYear: json['fiscalYear'] is int ? json['fiscalYear'] as int : null,
      assertedAt: requiredDate('assertedAt'),
      recordedAt: requiredDate('recordedAt'),
      source: FactSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => throw FormatException(
            'provenance « ${json['source']} » inconnue', json.toString()),  // lint-ignore
      ),
      status: FactStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => throw FormatException(
            'statut « ${json['status']} » inconnu', json.toString()),  // lint-ignore
      ),
      validUntil: optionalDate('validUntil'),
      needsConfirmation: json['needsConfirmation'] == true,
      supersedesVersionId: json['supersedesVersionId'] as String?,
      schemaVersion:
          json['schemaVersion'] is int ? json['schemaVersion'] as int : 1,
      consentRef: json['consentRef'] as String?,
    );
  }
}

/// Le reçu d'un calcul : quelles versions exactes l'ont nourri.
///
/// C'est ainsi que se répond « quels calculs dépendent de ce fait ? » — par
/// une requête sur les reçus, et non par un tableau inverse maintenu dans le
/// fait, qui dériverait au premier oubli. Effet de bord recherché : un chiffre
/// affiché peut dire de quoi il est fait.
class CalculationReceipt {
  const CalculationReceipt({
    required this.calculationId,
    required this.calculationType,
    required this.inputVersionIds,
    required this.computedAt,
    required this.rulesetVersion,
  });

  final String calculationId;
  final String calculationType;
  final List<String> inputVersionIds;
  final DateTime computedAt;

  /// Version du corps de règles appliqué — un même intrant peut donner deux
  /// résultats si le barème a changé.
  final String rulesetVersion;

  bool consumed(String versionId) => inputVersionIds.contains(versionId);

  Map<String, Object?> toJson() => {
        'calculationId': calculationId,
        'calculationType': calculationType,
        'inputVersionIds': inputVersionIds,
        'computedAt': computedAt.toUtc().toIso8601String(),
        'rulesetVersion': rulesetVersion,
      };
}
