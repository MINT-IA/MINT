import 'dart:convert';

import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';

/// Canonical, user-asserted 3a payments fact (Lego 5) — the first PLURAL
/// fact.
///
/// CONTRAT SÉMANTIQUE : une LISTE de versements atomiques — chaque entrée
/// porte un id stable opaque, un montant en centimes (int exact), la date de
/// crédit effective (jamais présumée égale à la date de saisie) et l'année
/// fiscale EXPLICITEMENT pinnée (depuis 2026 un rachat peut viser une année
/// antérieure : la date de crédit ne détermine plus seule l'année fiscale).
/// `totalForYearCents` est une VUE dérivée par agrégation — jamais le fait.
/// La soustraction plafond − total (marge CHF) est une sortie du moteur
/// attesté : elle n'existe nulle part ici. Un dépassement de plafond est
/// enregistré tel quel — jamais bloqué ni tronqué.
///
/// Invalidation PAR ANNÉE FISCALE : chaque mutation (ajout, correction,
/// suppression) bump la révision du bucket annuel concerné — déplacer une
/// entrée d'une année à l'autre bump les DEUX buckets ; corriger 2025 ne
/// périme jamais le contexte 2026.
class MintNextVersement3aEntry {
  const MintNextVersement3aEntry({
    required this.id,
    required this.amountCents,
    required this.creditedAt,
    required this.taxYear,
    this.accountRef,
  });

  /// Id stable opaque — une correction ne devient jamais suppression +
  /// doublon.
  final String id;
  final int amountCents;

  /// Date de crédit effective (UTC).
  final DateTime creditedAt;

  /// Année fiscale pinnée — jamais dérivée silencieusement de [creditedAt].
  final int taxYear;

  /// Référence de compte opaque (multi-comptes) — jamais l'établissement.
  final String? accountRef;

  Map<String, Object?> toJson() => {
        'id': id,
        'amount_cents': amountCents,
        'credited_at': creditedAt.toUtc().toIso8601String(),
        'tax_year': taxYear,
        if (accountRef != null) 'account_ref': accountRef,
      };

  static MintNextVersement3aEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final amount = raw['amount_cents'];
    final creditedAt = DateTime.tryParse(raw['credited_at']?.toString() ?? '');
    final taxYear = raw['tax_year'];
    final accountRef = raw['account_ref'];
    if (id is! String ||
        id.isEmpty ||
        amount is! int ||
        amount <= 0 ||
        creditedAt == null ||
        taxYear is! int ||
        taxYear < 1985 ||
        taxYear > 2100 ||
        (accountRef != null && accountRef is! String)) {
      return null;
    }
    return MintNextVersement3aEntry(
      id: id,
      amountCents: amount,
      creditedAt: creditedAt.toUtc(),
      taxYear: taxYear,
      accountRef: accountRef as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MintNextVersement3aEntry &&
      id == other.id &&
      amountCents == other.amountCents &&
      creditedAt == other.creditedAt &&
      taxYear == other.taxYear &&
      accountRef == other.accountRef;

  @override
  int get hashCode =>
      Object.hash(id, amountCents, creditedAt, taxYear, accountRef);
}

class MintNextVersements3aFact implements ConfirmedVersements3aSource {
  static const userDeclarationSource = 'user_declaration';

  /// Borne dure de la liste : le bundle scellé est un item unique — au-delà,
  /// l'écriture est refusée explicitement (jamais silencieusement tronquée).
  /// ~500 entrées ≈ 60 Ko JSON, très sous les limites keychain observées.
  static const maxEntries = 500;

  /// Révision stable d'un bucket jamais touché — indépendante des mutations
  /// des AUTRES années (l'isolation annuelle est un invariant).
  static const untouchedBucketRevision = 'untouched';

  static const entriesKey = 'q_versements_3a_fact_entries';
  static const bucketRevisionsKey = 'q_versements_3a_fact_bucket_revisions';
  static const assertedAtKey = 'q_versements_3a_fact_asserted_at';
  static const sourceKey = 'q_versements_3a_fact_source';
  static const schemaVersionKey = 'q_versements_3a_fact_schema_version';
  static const needsConfirmationKey =
      'q_versements_3a_fact_needs_confirmation';

  /// Complete owned bundle — committed and deleted atomically by the sealed
  /// canonical record.
  static const wizardKeys = <String>{
    entriesKey,
    bucketRevisionsKey,
    'q_versements_3a_fact_mutation_count',
    assertedAtKey,
    sourceKey,
    schemaVersionKey,
    needsConfirmationKey,
  };

  final List<MintNextVersement3aEntry> entries;

  /// Révision par bucket annuel — maintenue à chaque mutation (la
  /// suppression bump aussi l'année : `max(updatedAt)` des entrées restantes
  /// ne suffirait pas).
  final Map<int, String> bucketRevisions;

  /// Compteur de mutations — deux mutations au même instant produisent des
  /// révisions distinctes (l'horodatage seul est un fingerprint insuffisant).
  final int mutationCount;
  final DateTime assertedAt;
  final String source;
  final int schemaVersion;
  final bool needsConfirmation;

  const MintNextVersements3aFact({
    required this.entries,
    required this.bucketRevisions,
    this.mutationCount = 0,
    required this.assertedAt,
    required this.source,
    required this.schemaVersion,
    required this.needsConfirmation,
  });

  static MintNextVersements3aFact empty({required DateTime at}) =>
      MintNextVersements3aFact(
        entries: const [],
        bucketRevisions: const {},
        assertedAt: at.toUtc(),
        source: userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  /// Fingerprint global (dernier commit).
  String get revision => assertedAt.toUtc().toIso8601String();

  /// Révision du bucket annuel — null si l'année n'a jamais été touchée.
  String? bucketRevision(int taxYear) => bucketRevisions[taxYear];

  @override
  MintNext3aVersementsContext? toConfirmedVersementsContext(int taxYear) =>
      needsConfirmation
          ? null
          : MintNext3aVersementsContext(
              taxYear: taxYear,
              totalVerseAnnualCents: totalForYearCents(taxYear),
              // Bucket jamais touché → révision stable indépendante des
              // autres années — jamais la révision globale (elle changerait
              // quand 2025 bouge et invaliderait 2026 à tort).
              bucketRevision:
                  bucketRevision(taxYear) ?? untouchedBucketRevision,
            );

  /// VUE dérivée — l'agrégation de faits est permise ; la soustraction d'un
  /// plafond légal ne l'est pas (moteur attesté).
  int totalForYearCents(int taxYear) => entries
      .where((e) => e.taxYear == taxYear)
      .fold(0, (sum, e) => sum + e.amountCents);

  List<MintNextVersement3aEntry> entriesForYear(int taxYear) =>
      entries.where((e) => e.taxYear == taxYear).toList();

  Set<int> get taxYears => entries.map((e) => e.taxYear).toSet();

  MintNextVersement3aEntry? entryById(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  MintNextVersements3aFact _with({
    required List<MintNextVersement3aEntry> entries,
    required Map<int, String> bucketRevisions,
    required DateTime at,
  }) =>
      MintNextVersements3aFact(
        entries: entries,
        bucketRevisions: bucketRevisions,
        mutationCount: mutationCount + 1,
        assertedAt: at.toUtc(),
        source: source,
        schemaVersion: schemaVersion,
        needsConfirmation: needsConfirmation,
      );

  /// Deux mutations au même instant restent distinguables.
  String _revisionStamp(DateTime at) =>
      '${at.toUtc().toIso8601String()}#${mutationCount + 1}';

  Map<int, String> _bumped(Iterable<int> years, DateTime at) {
    final next = Map<int, String>.from(bucketRevisions);
    final stamp = _revisionStamp(at);
    for (final year in years) {
      next[year] = stamp;
    }
    return next;
  }

  /// L'unicité des ids est un INVARIANT du modèle — pas une promesse d'un
  /// écran : un doublon rendrait le fait scellé illisible au prochain
  /// parsing. Le dépassement de la borne est refusé, jamais tronqué.
  MintNextVersements3aFact withEntryAdded(
      MintNextVersement3aEntry entry, DateTime at) {
    if (entryById(entry.id) != null) {
      throw ArgumentError.value(
          entry.id, 'entry.id', 'duplicate entry id — ids are an invariant');
    }
    if (entries.length >= maxEntries) {
      throw StateError('versements list is at its hard bound ($maxEntries)');
    }
    return _with(
      entries: [...entries, entry],
      bucketRevisions: _bumped([entry.taxYear], at),
      at: at,
    );
  }

  /// Correction par id stable — jamais suppression + doublon, jamais
  /// silencieuse : un id inconnu (état UI périmé) ou un changement d'id
  /// est refusé explicitement.
  MintNextVersements3aFact withEntryUpdated(
      String id, MintNextVersement3aEntry updated, DateTime at) {
    final previous = entryById(id);
    if (previous == null) {
      throw ArgumentError.value(
          id, 'id', 'unknown entry id — a stale correction must surface');
    }
    if (updated.id != id) {
      throw ArgumentError.value(updated.id, 'updated.id',
          'entry ids are immutable — corrections never change identity');
    }
    return _with(
      entries: [
        for (final e in entries) e.id == id ? updated : e,
      ],
      bucketRevisions: _bumped({previous.taxYear, updated.taxYear}, at),
      at: at,
    );
  }

  MintNextVersements3aFact withEntryRemoved(String id, DateTime at) {
    final previous = entryById(id);
    if (previous == null) {
      throw ArgumentError.value(
          id, 'id', 'unknown entry id — a stale deletion must surface');
    }
    return _with(
      entries: entries.where((e) => e.id != id).toList(),
      bucketRevisions: _bumped([previous.taxYear], at),
      at: at,
    );
  }

  static const mutationCountKey = 'q_versements_3a_fact_mutation_count';

  Map<String, dynamic> toWizardAnswers() => <String, dynamic>{
        entriesKey: json.encode([for (final e in entries) e.toJson()]),
        bucketRevisionsKey: json.encode(
            bucketRevisions.map((year, rev) => MapEntry('$year', rev))),
        mutationCountKey: mutationCount,
        assertedAtKey: assertedAt.toUtc().toIso8601String(),
        sourceKey: source,
        schemaVersionKey: schemaVersion,
        needsConfirmationKey: needsConfirmation,
      };

  static Map<String, dynamic> deletionWizardAnswers() =>
      <String, dynamic>{for (final key in wizardKeys) key: null};

  static MintNextVersements3aFact? fromWizardAnswers(
      Map<String, dynamic> answers) {
    final rawEntries = answers[entriesKey];
    final rawRevisions = answers[bucketRevisionsKey];
    final mutationCount = _int(answers[mutationCountKey]);
    final assertedAt =
        DateTime.tryParse(answers[assertedAtKey]?.toString() ?? '');
    final source = answers[sourceKey];
    final schema = _int(answers[schemaVersionKey]);
    final confirmation = answers[needsConfirmationKey];
    if (rawEntries is! String ||
        rawRevisions is! String ||
        mutationCount == null ||
        mutationCount < 0 ||
        assertedAt == null ||
        source is! String ||
        source.isEmpty ||
        schema == null ||
        confirmation is! bool) {
      return null;
    }
    final List<MintNextVersement3aEntry> entries;
    final Map<int, String> revisions;
    try {
      final decodedEntries = json.decode(rawEntries);
      if (decodedEntries is! List) return null;
      final parsed = decodedEntries
          .map(MintNextVersement3aEntry.fromJson)
          .toList(growable: false);
      if (parsed.any((e) => e == null)) return null;
      entries = parsed.cast<MintNextVersement3aEntry>();
      final ids = entries.map((e) => e.id).toSet();
      if (ids.length != entries.length) return null;
      // La borne s'applique aussi au parsing : un payload scellé au-delà de
      // la borne est corrompu par définition — jamais chargé, jamais tronqué.
      if (entries.length > maxEntries) return null;
      final decodedRevisions = json.decode(rawRevisions);
      if (decodedRevisions is! Map) return null;
      revisions = {};
      for (final entry in decodedRevisions.entries) {
        final year = int.tryParse(entry.key.toString());
        final rev = entry.value;
        if (year == null || rev is! String || rev.isEmpty) return null;
        revisions[year] = rev;
      }
      // Toute année portant des entrées doit avoir un bucket — un bucket
      // orphelin (année vidée par suppression) reste valide.
      for (final e in entries) {
        if (!revisions.containsKey(e.taxYear)) return null;
      }
    } on FormatException {
      return null;
    }
    return MintNextVersements3aFact(
      entries: entries,
      bucketRevisions: revisions,
      mutationCount: mutationCount,
      assertedAt: assertedAt.toUtc(),
      source: source,
      schemaVersion: schema,
      needsConfirmation: confirmation,
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      return value.isFinite && value == value.truncateToDouble()
          ? value.toInt()
          : null;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
