/// Canonical, user-asserted income fact (Lego 3).
///
/// CONTRAT SÉMANTIQUE : le fait capture le REVENU NET ENCAISSÉ par période —
/// ce que la personne reçoit réellement sur son compte. Ce n'est NI le
/// salaire brut NI le revenu net imposable/AVS : toute conversion vers un
/// « revenu déterminant » fiscal est la responsabilité du consommateur,
/// jamais du fait. Montant en centimes (int), période explicite.
///
/// Clés POSSÉDÉES (jamais partagées) + PROJECTION écriture seule vers les
/// clés legacy `q_net_income_period_chf` / `q_pay_frequency` (consommateurs
/// historiques : budget, CoachProfile). Les writers legacy restent intacts ;
/// leurs écritures ne créent pas de fait et ne survivent pas à la projection
/// quand un fait confirmé existe. La normalisation annuelle (×12 si mensuel)
/// est appliquée UNE seule fois, à la frontière du consommateur, via
/// [annualizedCents].
enum MintNextRevenuPeriod { monthly, yearly }

extension MintNextRevenuPeriodId on MintNextRevenuPeriod {
  String get id => switch (this) {
        MintNextRevenuPeriod.monthly => 'monthly',
        MintNextRevenuPeriod.yearly => 'yearly',
      };
}

class MintNextRevenuFact {
  static const userDeclarationSource = 'user_declaration';

  static const amountCentsKey = 'q_revenu_fact_amount_cents';
  static const periodKey = 'q_revenu_fact_period';
  static const assertedAtKey = 'q_revenu_fact_asserted_at';
  static const sourceKey = 'q_revenu_fact_source';
  static const schemaVersionKey = 'q_revenu_fact_schema_version';
  static const needsConfirmationKey = 'q_revenu_fact_needs_confirmation';

  /// Projection legacy — écrite à chaque commit canonique, jamais lue comme
  /// source du fait. `q_net_income_period_chf` est en CHF par période (les
  /// consommateurs historiques lisent un double), `q_pay_frequency` reçoit
  /// les tokens que `CoachProfile.fromWizardAnswers` normalise déjà.
  static const legacyAmountKey = 'q_net_income_period_chf';
  static const legacyFrequencyKey = 'q_pay_frequency';

  /// Complete owned bundle — committed and deleted atomically by the sealed
  /// canonical record.
  static const wizardKeys = <String>{
    amountCentsKey,
    periodKey,
    assertedAtKey,
    sourceKey,
    schemaVersionKey,
    needsConfirmationKey,
  };

  final int amountCents;
  final MintNextRevenuPeriod period;
  final DateTime assertedAt;
  final String source;
  final int schemaVersion;
  final bool needsConfirmation;

  const MintNextRevenuFact({
    required this.amountCents,
    required this.period,
    required this.assertedAt,
    required this.source,
    required this.schemaVersion,
    required this.needsConfirmation,
  });

  /// Revision fingerprint binding fiscal derivatives to this assertion.
  String get revision => assertedAt.toUtc().toIso8601String();

  /// Normalisation annuelle — appliquée UNE seule fois, ici et nulle part
  /// ailleurs : le montant stocké reste toujours le montant par période
  /// déclaré (anti-double-×12).
  int get annualizedCents => switch (period) {
        MintNextRevenuPeriod.monthly => amountCents * 12,
        MintNextRevenuPeriod.yearly => amountCents,
      };

  Map<String, dynamic> toWizardAnswers() => <String, dynamic>{
        amountCentsKey: amountCents,
        periodKey: period.id,
        assertedAtKey: assertedAt.toUtc().toIso8601String(),
        sourceKey: source,
        schemaVersionKey: schemaVersion,
        needsConfirmationKey: needsConfirmation,
      };

  /// Projection legacy jointe au même commit canonique que le bundle.
  Map<String, dynamic> legacyProjectionAnswers() => <String, dynamic>{
        legacyAmountKey: amountCents / 100.0,
        legacyFrequencyKey: period.id,
      };

  /// Le tombstone purge le bundle possédé ET la projection legacy — sans
  /// quoi les consommateurs historiques continueraient d'afficher un revenu
  /// que la personne a supprimé.
  static Map<String, dynamic> deletionWizardAnswers() => <String, dynamic>{
        for (final key in wizardKeys) key: null,
        legacyAmountKey: null,
        legacyFrequencyKey: null,
      };

  static MintNextRevenuFact? fromWizardAnswers(Map<String, dynamic> answers) {
    final amount = _int(answers[amountCentsKey]);
    final period = _period(answers[periodKey]);
    final assertedAt =
        DateTime.tryParse(answers[assertedAtKey]?.toString() ?? '');
    final source = answers[sourceKey];
    final schema = _int(answers[schemaVersionKey]);
    final confirmation = answers[needsConfirmationKey];
    if (amount == null ||
        amount <= 0 ||
        period == null ||
        assertedAt == null ||
        source is! String ||
        source.isEmpty ||
        schema == null ||
        confirmation is! bool) {
      return null;
    }
    return MintNextRevenuFact(
      amountCents: amount,
      period: period,
      assertedAt: assertedAt.toUtc(),
      source: source,
      schemaVersion: schema,
      needsConfirmation: confirmation,
    );
  }

  static MintNextRevenuPeriod? _period(dynamic value) {
    for (final item in MintNextRevenuPeriod.values) {
      if (item.id == value) return item;
    }
    return null;
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

  @override
  bool operator ==(Object other) =>
      other is MintNextRevenuFact &&
      amountCents == other.amountCents &&
      period == other.period &&
      assertedAt == other.assertedAt &&
      source == other.source &&
      schemaVersion == other.schemaVersion &&
      needsConfirmation == other.needsConfirmation;

  @override
  int get hashCode => Object.hash(
      amountCents, period, assertedAt, source, schemaVersion, needsConfirmation);
}
