// Le contrat canonique des faits — ce que le jumeau a le droit de porter.
//
// POURQUOI CE FICHIER EXISTE, ET POURQUOI IL BLOQUAIT LA SUITE
//
// Une relecture du registre a posé la question « qu'est-ce qui, faute d'être
// fait maintenant, coûtera dix fois plus cher dans six mois ? ». La réponse
// tenait en deux constats.
//
// Les faits NATURELLEMENT MULTIPLES étaient impossibles. Trois comptes 3a,
// deux hypothèques, plusieurs employeurs : sous un identifiant unique, chaque
// écriture remplaçait la précédente ; sous des identités inventées au vol, la
// projection levait un conflit. Pluralité théorique dans le registre,
// écrasement ou exception dans le produit. Et la doctrine réclame précisément
// « répartir plusieurs comptes 3a ».
//
// Et le coach ne pouvait pas SAVOIR CE QU'IL IGNORE. Un champ nul ne dit pas
// s'il est inconnu, confirmé absent, sans objet, périmé ou en attente de
// confirmation. Or « il me manque X pour te répondre » suppose exactement
// cette distinction.
//
// Ce catalogue déclare donc, pour chaque type de fait : sa cardinalité, la
// règle qui identifie un membre quand il y en a plusieurs, le temps métier
// auquel il se rapporte, et les états de connaissance qui ont un sens pour
// lui. Le registre le fait respecter.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

/// Combien d'exemplaires d'un même type peuvent coexister.
enum FactCardinality {
  /// Un seul, qui se remplace. Le domicile fiscal, l'état civil.
  single,

  /// Plusieurs à la fois, chacun avec sa propre histoire. Les comptes 3a, les
  /// hypothèques, les employeurs. Chaque membre porte une clé qui le distingue
  /// et qui NE CHANGE PAS — sinon deux versions du même compte deviendraient
  /// deux comptes.
  multiple,
}

/// À quel temps métier la valeur se rapporte.
enum FactTemporality {
  /// Vaut depuis une date et jusqu'à une autre : le domicile, l'état civil.
  interval,

  /// Appartient à un exercice fiscal : les intérêts hypothécaires, les
  /// versements 3a. La charge d'une année ne se reporte pas.
  fiscalYear,

  /// Vaut à l'instant où on le déclare, sans période propre : l'affiliation
  /// LPP telle qu'on la constate aujourd'hui.
  pointInTime,
}

/// Ce que MINT sait — ou ne sait pas — d'un fait.
///
/// Cinq états là où un champ nul n'en distinguait aucun. C'est cette
/// distinction qui permet au coach de dire « il me manque X » plutôt que de
/// se taire, et surtout de ne PAS redemander ce qui a déjà été répondu.
enum FactKnowledge {
  /// Jamais demandé, jamais déclaré. Appelle une collecte.
  unknown,

  /// Déclaré et confirmé. Utilisable.
  known,

  /// La personne a répondu « je n'en ai pas ». Ce n'est pas un trou : c'est
  /// une réponse, et la redemander serait une relance.
  confirmedAbsent,

  /// La question ne se pose pas pour cette personne — les intérêts
  /// hypothécaires d'un locataire, la commune fiscale de quelqu'un sans
  /// domicile suisse. Ne jamais demander.
  notApplicable,

  /// Déclaré, mais la valeur a probablement vieilli. Appelle une mise à jour,
  /// pas une première collecte — la question posée n'est pas la même.
  stale,

  /// Extrait d'un document ou reçu d'une institution, en attente de
  /// confirmation par la personne. N'alimente aucun calcul tant qu'elle n'a
  /// pas confirmé.
  toConfirm,
}

/// La déclaration d'un type de fait.
class FactContract {
  const FactContract({
    required this.factType,
    required this.cardinality,
    required this.temporality,
    required this.identityRule,
    this.applicability,
  });

  final String factType;
  final FactCardinality cardinality;
  final FactTemporality temporality;

  /// Ce qui distingue un membre des autres, en clair.
  ///
  /// Pour un fait unique : « le seul ». Pour un fait multiple : la règle qui
  /// donne sa clé, et qui doit être STABLE — un compte 3a identifié par son
  /// établissement et son numéro reste le même compte quand son solde change.
  final String identityRule;

  /// Ce qui rend ce fait sans objet, quand c'est le cas.
  ///
  /// Null = toujours applicable. Sinon, une phrase qui dit quand la question
  /// ne se pose pas — pour que MINT ne la pose jamais à quelqu'un qu'elle ne
  /// concerne pas.
  final String? applicability;

  bool get isMultiple => cardinality == FactCardinality.multiple;

  /// L'identifiant complet d'un membre.
  ///
  /// Un fait unique n'accepte PAS de clé de membre : en accepter une ferait
  /// silencieusement coexister deux domiciles.
  String factIdFor({String? memberKey}) {
    if (!isMultiple) {
      if (memberKey != null) {
        throw ArgumentError(
            'le fait « $factType » est unique : il n\'accepte pas de clé de '
            'membre (« $memberKey »)');  // lint-ignore
      }
      return factType;
    }
    if (memberKey == null || memberKey.isEmpty) {
      throw ArgumentError(
          'le fait « $factType » est multiple : il exige une clé de membre '
          '($identityRule)');  // lint-ignore
    }
    if (memberKey.contains(FactContracts.memberSeparator)) {
      throw ArgumentError(
          'la clé de membre « $memberKey » contient le séparateur réservé '
          '« ${FactContracts.memberSeparator} »');  // lint-ignore
    }
    return '$factType${FactContracts.memberSeparator}$memberKey';
  }
}

/// Le catalogue. Un type de fait absent d'ici n'a pas le droit d'exister dans
/// le registre — c'est ce qui empêche chaque nouvel écran d'inventer son
/// propre pseudo-identifiant.
class FactContracts {
  const FactContracts._();

  /// Sépare le type de la clé de membre. Réservé : une clé qui le contiendrait
  /// rendrait l'identifiant ambigu.
  static const memberSeparator = '#';

  static const List<FactContract> all = [
    FactContract(
      factType: 'domicile',
      cardinality: FactCardinality.single,
      temporality: FactTemporality.interval,
      identityRule: 'un seul domicile fiscal à la fois',
    ),
    FactContract(
      factType: 'etat_civil',
      cardinality: FactCardinality.single,
      temporality: FactTemporality.interval,
      identityRule: 'un seul état civil à la fois',
    ),
    FactContract(
      factType: 'revenu',
      cardinality: FactCardinality.multiple,
      temporality: FactTemporality.fiscalYear,
      identityRule: "l'employeur ou la source du revenu",
      applicability: 'sans objet pour quelqu\'un sans activité déclarée',
    ),
    FactContract(
      factType: 'logement',
      cardinality: FactCardinality.multiple,
      temporality: FactTemporality.fiscalYear,
      identityRule: "le bien concerné — résidence principale, secondaire, "
          "objet de rendement",
    ),
    FactContract(
      factType: 'lpp_affiliation',
      cardinality: FactCardinality.multiple,
      temporality: FactTemporality.pointInTime,
      identityRule: "la caisse de pension",
      applicability: 'sans objet pour un indépendant non affilié',
    ),
    FactContract(
      factType: 'versements_3a',
      cardinality: FactCardinality.multiple,
      temporality: FactTemporality.fiscalYear,
      // La règle disait « l'établissement et le compte ». La donnée, elle,
      // porte des VERSEMENTS — chacun avec son identifiant stable opaque, son
      // montant, sa date de crédit et son année fiscale épinglée. Le contrat
      // décrivait donc un monde différent de celui qui existe, et l'écart
      // n'est apparu qu'en tentant la décomposition.
      identityRule: "l'identifiant stable du versement — c'est lui qui fait " // lint-ignore
          "qu'une correction reste une correction, et ne devient jamais une " // lint-ignore
          "suppression suivie d'un doublon", // lint-ignore
    ),
  ];

  static FactContract? of(String factType) {
    for (final contract in all) {
      if (contract.factType == factType) return contract;
    }
    return null;
  }

  /// Le type porté par un identifiant, membre compris.
  static String typeOf(String factId) {
    final index = factId.indexOf(memberSeparator);
    return index < 0 ? factId : factId.substring(0, index);
  }

  /// La clé de membre, ou null pour un fait unique.
  static String? memberOf(String factId) {
    final index = factId.indexOf(memberSeparator);
    return index < 0 ? null : factId.substring(index + 1);
  }

  /// Cet identifiant respecte-t-il le contrat de son type ?
  ///
  /// Rend la raison du refus, ou null si tout va bien.
  static String? violation(String factId) {
    final type = typeOf(factId);
    final contract = of(type);
    if (contract == null) {
      return 'type de fait « $type » absent du catalogue';
    }
    final member = memberOf(factId);
    if (contract.isMultiple && (member == null || member.isEmpty)) {
      return 'le fait « $type » est multiple : il exige une clé de membre '
          '(${contract.identityRule})';
    }
    if (!contract.isMultiple && member != null) {
      return 'le fait « $type » est unique : il n\'accepte pas de clé de membre';
    }
    return null;
  }
}
