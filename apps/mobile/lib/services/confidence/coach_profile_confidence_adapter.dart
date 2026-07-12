import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';

/// Adapts the canonical ledger profile to the enhanced-confidence input shape.
class CoachProfileConfidenceAdapter {
  const CoachProfileConfidenceAdapter._();

  static ConfidenceResult compute(CoachProfile profile) {
    bool proven(String profilePath, Iterable<String> markers) =>
        profile.dataSources.containsKey(profilePath) ||
        markers.any(profile.userProvidedFields.contains);
    dynamic fact(
      String profilePath,
      Iterable<String> markers,
      dynamic value,
    ) =>
        proven(profilePath, markers) ? value : null;

    final profileMap = <String, dynamic>{
      'age': fact(
        'age',
        const ['age'],
        profile.birthYear > 0 ? DateTime.now().year - profile.birthYear : null,
      ),
      'canton': fact(
        'canton',
        const ['canton'],
        profile.canton.isEmpty ? null : profile.canton,
      ),
      'salaire_brut': fact(
        'salaireBrutMensuel',
        const ['salary', 'grossSalaryAnnual'],
        profile.salaireBrutMensuel,
      ),
      'salaire_net': fact(
        'monthlyNetIncomeDeclared',
        const ['netIncome'],
        profile.monthlyNetIncomeDeclared,
      ),
      'lpp_total': fact(
        'prevoyance.avoirLppTotal',
        const [],
        profile.prevoyance.avoirLppTotal,
      ),
      'lpp_obligatoire': fact(
        'prevoyance.avoirLppObligatoire',
        const [],
        profile.prevoyance.avoirLppObligatoire,
      ),
      'lpp_surobligatoire': fact(
        'prevoyance.avoirLppSurobligatoire',
        const [],
        profile.prevoyance.avoirLppSurobligatoire,
      ),
      'lpp_insured_salary': fact(
        'prevoyance.salaireAssure',
        const [],
        profile.prevoyance.salaireAssure,
      ),
      'conversion_rate_oblig': fact(
        'prevoyance.tauxConversion',
        const [],
        profile.prevoyance.tauxConversion,
      ),
      'conversion_rate_suroblig': fact(
        'prevoyance.tauxConversionSuroblig',
        const [],
        profile.prevoyance.tauxConversionSuroblig,
      ),
      'buyback_potential': fact(
        'prevoyance.rachatMaximum',
        const [],
        profile.prevoyance.rachatMaximum,
      ),
      'avs_contribution_years': fact(
        'prevoyance.anneesContribuees',
        const [],
        profile.prevoyance.anneesContribuees,
      ),
      'avs_ramd': fact(
        'prevoyance.ramd',
        const [],
        profile.prevoyance.ramd,
      ),
      'pillar_3a_balance': fact(
        'prevoyance.totalEpargne3a',
        const [],
        profile.prevoyance.totalEpargne3a,
      ),
      'mortgage_remaining': fact(
        'dettes.hypotheque',
        const ['mortgageBalance'],
        profile.dettes.hypotheque,
      ),
      'property_value': fact(
        'patrimoine.propertyMarketValue',
        const ['propertyMarketValue'],
        profile.patrimoine.immobilierEffectif,
      ),
      'is_married': fact(
        'etatCivil',
        const ['civilStatus'],
        profile.etatCivil == CoachCivilStatus.marie,
      ),
      'nb_children': fact(
        'nombreEnfants',
        const ['children'],
        profile.nombreEnfants,
      ),
      'monthly_expenses': fact(
        'depenses.totalMensuel',
        const ['monthlyExpenses'],
        profile.depenses.totalMensuel,
      ),
      'is_independant': fact(
        'employmentStatus',
        const ['employmentStatus'],
        profile.employmentStatus == 'independant',
      ),
      'has_lpp': fact(
        'prevoyance.hasPensionFund',
        const ['hasPensionFund'],
        profile.prevoyance.hasPensionFund,
      ),
    };

    final fieldSources = <FieldSource>[
      for (final entry in profile.dataSources.entries)
        if (profileMap[_confidenceFieldName(entry.key)] != null)
          FieldSource(
            fieldName: _confidenceFieldName(entry.key),
            source: _confidenceDataSource(entry.value),
            updatedAt: profile.dataTimestamps[entry.key] ?? profile.createdAt,
            value: profileMap[_confidenceFieldName(entry.key)],
          ),
    ];

    return EnhancedConfidenceService.computeConfidence(
      profileMap,
      fieldSources,
      literacyLevel: profile.financialLiteracyLevel.name,
      checkInCount: profile.checkIns.length,
    );
  }

  static String _confidenceFieldName(String profilePath) {
    return const <String, String>{
          'birthYear': 'age',
          'canton': 'canton',
          'salaireBrutMensuel': 'salaire_brut',
          'monthlyNetIncomeDeclared': 'salaire_net',
          'prevoyance.avoirLppTotal': 'lpp_total',
          'prevoyance.avoirLppObligatoire': 'lpp_obligatoire',
          'prevoyance.avoirLppSurobligatoire': 'lpp_surobligatoire',
          'prevoyance.salaireAssure': 'lpp_insured_salary',
          'prevoyance.tauxConversion': 'conversion_rate_oblig',
          'prevoyance.tauxConversionSuroblig': 'conversion_rate_suroblig',
          'prevoyance.rachatMaximum': 'buyback_potential',
          'prevoyance.anneesContribuees': 'avs_contribution_years',
          'prevoyance.ramd': 'avs_ramd',
          'prevoyance.totalEpargne3a': 'pillar_3a_balance',
          'dettes.hypotheque': 'mortgage_remaining',
          'patrimoine.propertyMarketValue': 'property_value',
          'etatCivil': 'is_married',
          'nombreEnfants': 'nb_children',
          'depenses.totalMensuel': 'monthly_expenses',
          'employmentStatus': 'is_independant',
        }[profilePath] ??
        profilePath;
  }

  static DataSource _confidenceDataSource(ProfileDataSource source) {
    return switch (source) {
      ProfileDataSource.estimated => DataSource.systemEstimate,
      ProfileDataSource.userInput => DataSource.userEntry,
      ProfileDataSource.crossValidated => DataSource.userEntryCrossValidated,
      ProfileDataSource.certificate => DataSource.documentScanVerified,
      ProfileDataSource.openBanking => DataSource.openBanking,
    };
  }
}
