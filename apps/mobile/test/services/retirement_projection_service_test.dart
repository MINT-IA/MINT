import 'dart:ui';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

/// Tests for RetirementProjectionService — unified household retirement projection.
///
/// Legal basis: LAVS art. 21-40, LPP art. 14-16, LIFD art. 38, OPC.
/// Golden couple: Julien (1977, 122'207 CHF) + Lauren (1982, 67'000 CHF).
void main() {
  /// Minimal profile helper.
  CoachProfile buildProfile({
    String? firstName,
    int birthYear = 1977,
    String canton = 'VS',
    double salaireBrutMensuel = 10000,
    double nombreDeMois = 12.0,
    String employmentStatus = 'salarie',
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    ConjointProfile? conjoint,
    double avoirLppTotal = 70000,
    double? salaireAssure,
    double rendementCaisse = 0.02,
    double tauxConversion = lppTauxConversionMinDecimal,
    bool canContribute3a = true,
    double totalEpargne3a = 32000,
    double epargneLiquide = 50000,
    double investissements = 100000,
    int? arrivalAge,
    int? lacunesAvs = 0,
    double? avsRamd,
    int? avsContributionYears,
    double? monthlyAvsEstimate,
    AvsGapStatus? avsGapStatus,
    Map<String, ProfileDataSource> dataSources = const {
      AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
    },
    Map<String, DateTime> dataTimestamps = const {},
    List<PlannedMonthlyContribution> contributions = const [],
  }) {
    return CoachProfile(
      firstName: firstName,
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      nombreDeMois: nombreDeMois,
      employmentStatus: employmentStatus,
      etatCivil: etatCivil,
      conjoint: conjoint,
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLppTotal,
        salaireAssure: salaireAssure,
        rendementCaisse: rendementCaisse,
        tauxConversion: tauxConversion,
        canContribute3a: canContribute3a,
        totalEpargne3a: totalEpargne3a,
        lacunesAVS: lacunesAvs,
        ramd: avsRamd,
        anneesContribuees: avsContributionYears,
        renteAVSEstimeeMensuelle: monthlyAvsEstimate,
      ),
      patrimoine: PatrimoineProfile(
        epargneLiquide: epargneLiquide,
        investissements: investissements,
      ),
      arrivalAge: arrivalAge,
      avsGapStatus: avsGapStatus,
      dataSources: dataSources,
      dataTimestamps: dataTimestamps,
      plannedContributions: contributions,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 1),
        label: 'Retraite',
      ),
    );
  }

  double expectedLppMonthlyFromCore(
    CoachProfile profile, {
    double lppCapitalPct = 0,
  }) {
    const retirementAge = avsAgeReferenceHomme;
    final grossAnnualSalary = (profile.prevoyance.salaireAssure != null &&
            profile.prevoyance.salaireAssure! > 0)
        ? profile.prevoyance.salaireAssure!
        : profile.revenuBrutAnnuel;
    final annualRente = LppCalculator.projectToRetirement(
      currentBalance: profile.prevoyance.avoirLppTotal ?? 0,
      currentAge: profile.age,
      retirementAge: retirementAge,
      grossAnnualSalary: grossAnnualSalary,
      caisseReturn: profile.prevoyance.rendementCaisse,
      conversionRate: profile.prevoyance.tauxConversion,
    );
    final adjustedRate = LppCalculator.adjustedConversionRate(
      baseRate: profile.prevoyance.tauxConversion,
      retirementAge: retirementAge,
    );
    return LppCalculator.blendedMonthly(
      annualRente: annualRente,
      conversionRate: adjustedRate,
      lppCapitalPct: lppCapitalPct,
      canton: profile.canton,
      isMarried: profile.etatCivil == CoachCivilStatus.marie,
    );
  }

  group('RetirementProjectionService.project — B2 AVS hard floor', () {
    void expectAlwaysPartial(
      RetirementProjectionResult result, {
      required List<String> missingFields,
    }) {
      expect(result.avsIncluded, isFalse);
      expect(result.revenuMensuelAt65, isNull);
      expect(result.tauxRemplacement, isNull);
      expect(result.missingFields, missingFields);
      expect(result.revenuMensuelHorsAvs, greaterThan(0));
      expect(result.budgetGap, isNull);
      expect(result.phases, isEmpty);
      expect(result.indexedProjection, isEmpty);
    }

    test('all declared statuses stay partial', () {
      for (final status in AvsGapStatus.values) {
        final result = RetirementProjectionService.project(
          profile: buildProfile(
            lacunesAvs: status == AvsGapStatus.noGaps ? 0 : 7,
            avsGapStatus: status,
            dataSources: const {},
          ),
        );

        expectAlwaysPartial(
          result,
          missingFields: const [ForecasterService.selfAvsPensionFieldPath],
        );
      }
    });

    test('certificate-backed gap and legacy AVS amounts stay partial', () {
      final profile = buildProfile(
        lacunesAvs: 3,
        avsRamd: 120000,
        avsContributionYears: 44,
        monthlyAvsEstimate: 2520,
        dataSources: const {
          AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
          'prevoyance.ramd': ProfileDataSource.certificate,
          'prevoyance.anneesContribuees': ProfileDataSource.certificate,
          'prevoyance.renteAVSEstimeeMensuelle': ProfileDataSource.certificate,
        },
        dataTimestamps: {
          AvsGapEvidence.selfFieldPath: DateTime(2026, 7, 13),
          'prevoyance.ramd': DateTime(2026, 7, 13),
          'prevoyance.anneesContribuees': DateTime(2026, 7, 13),
          'prevoyance.renteAVSEstimeeMensuelle': DateTime(2026, 7, 13),
        },
      );

      final result = RetirementProjectionService.project(profile: profile);

      expectAlwaysPartial(
        result,
        missingFields: const [ForecasterService.selfAvsPensionFieldPath],
      );
    });

    test('legacy certificate-tagged couple inputs stay partial', () {
      final profile = buildProfile(
        firstName: 'Julien',
        lacunesAvs: 0,
        avsRamd: 120000,
        avsContributionYears: 44,
        monthlyAvsEstimate: 2520,
        etatCivil: CoachCivilStatus.marie,
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 5500,
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 50000,
            lacunesAVS: 0,
            ramd: 66000,
            anneesContribuees: 25,
            renteAVSEstimeeMensuelle: 2000,
          ),
        ),
        dataSources: const {
          AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
          AvsGapEvidence.spouseFieldPath: ProfileDataSource.certificate,
          'prevoyance.ramd': ProfileDataSource.certificate,
          'prevoyance.anneesContribuees': ProfileDataSource.certificate,
          'prevoyance.renteAVSEstimeeMensuelle': ProfileDataSource.certificate,
          'conjoint.prevoyance.ramd': ProfileDataSource.certificate,
          'conjoint.prevoyance.anneesContribuees':
              ProfileDataSource.certificate,
          'conjoint.prevoyance.renteAVSEstimeeMensuelle':
              ProfileDataSource.certificate,
        },
        dataTimestamps: {
          AvsOfficialPensionEvidence.selfFieldPath: DateTime(2026, 7, 13),
          AvsOfficialPensionEvidence.spouseFieldPath: DateTime(2026, 7, 13),
        },
      );

      final result = RetirementProjectionService.project(profile: profile);

      expectAlwaysPartial(
        result,
        missingFields: const [
          ForecasterService.selfAvsPensionFieldPath,
          ForecasterService.spouseAvsPensionFieldPath,
        ],
      );
      expect(result.isCouple, isTrue);
    });

    for (final status in const [
      CoachCivilStatus.marie,
      CoachCivilStatus.registeredPartnership,
    ]) {
      test('$status without conjoint remains partial, never zero', () {
        final result = RetirementProjectionService.project(
          profile: buildProfile(etatCivil: status),
        );

        expectAlwaysPartial(
          result,
          missingFields: const [
            ForecasterService.selfAvsPensionFieldPath,
            ForecasterService.spouseAvsPensionFieldPath,
          ],
        );
        expect(result.isCouple, isFalse);
      });
    }

    test('invalid current income keeps total rate and budget unknown', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(salaireBrutMensuel: 0),
      );

      expectAlwaysPartial(
        result,
        missingFields: const [ForecasterService.selfAvsPensionFieldPath],
      );
    });

    test('legacy AVS metadata cannot change known non-AVS income', () {
      final baseline = RetirementProjectionService.project(
        profile: buildProfile(
          lacunesAvs: null,
          dataSources: const {},
        ),
      );
      final legacyCertified = RetirementProjectionService.project(
        profile: buildProfile(
          lacunesAvs: 0,
          avsRamd: 120000,
          avsContributionYears: 44,
          monthlyAvsEstimate: 2520,
          dataSources: const {
            AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
            'prevoyance.ramd': ProfileDataSource.certificate,
            'prevoyance.anneesContribuees': ProfileDataSource.certificate,
            'prevoyance.renteAVSEstimeeMensuelle':
                ProfileDataSource.certificate,
          },
        ),
      );

      expect(
        legacyCertified.revenuMensuelHorsAvs,
        closeTo(baseline.revenuMensuelHorsAvs, 0.000001),
      );
    });

    test('missing spouse age and salary add no synthetic LPP bonifications',
        () {
      CoachProfile profile({required bool withOverrides}) {
        return buildProfile(
          etatCivil: CoachCivilStatus.marie,
          conjoint: ConjointProfile(
            prevoyance: PrevoyanceProfile(
              avoirLppTotal: 60000,
              salaireAssure: withOverrides ? 60000 : null,
              bonificationRate: withOverrides ? 0.18 : null,
              rendementCaisse: 0.02,
            ),
          ),
        );
      }

      final withOverrides = RetirementProjectionService.project(
        profile: profile(withOverrides: true),
      );
      final balanceOnly = RetirementProjectionService.project(
        profile: profile(withOverrides: false),
      );

      expectAlwaysPartial(
        withOverrides,
        missingFields: const [
          ForecasterService.selfAvsPensionFieldPath,
          ForecasterService.spouseAvsPensionFieldPath,
        ],
      );
      expect(
        withOverrides.revenuMensuelHorsAvs,
        closeTo(balanceOnly.revenuMensuelHorsAvs, 0.000001),
      );
    });

    test('capital withdrawal changes non-AVS income without unlocking AVS', () {
      final rente = RetirementProjectionService.project(
        profile: buildProfile(),
        lppCapitalPct: 0,
      );
      final capital = RetirementProjectionService.project(
        profile: buildProfile(),
        lppCapitalPct: 1,
      );

      expectAlwaysPartial(
        rente,
        missingFields: const [ForecasterService.selfAvsPensionFieldPath],
      );
      expectAlwaysPartial(
        capital,
        missingFields: const [ForecasterService.selfAvsPensionFieldPath],
      );
      expect(
        capital.revenuMensuelHorsAvs,
        isNot(equals(rente.revenuMensuelHorsAvs)),
      );
    });
  });

  group('RetirementProjectionService.project — non-AVS contract', () {
    test('standard salaried profile preserves capital-derived income', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );

      expect(result.revenuMensuelHorsAvs, greaterThan(0));
      expect(result.revenuMensuelAt65, isNull);
      expect(result.tauxRemplacement, isNull);
      expect(result.isCouple, isFalse);
    });

    test('independant without LPP preserves 3a and free assets only', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(
          employmentStatus: 'independant',
          avoirLppTotal: 0,
          salaireBrutMensuel: 8000,
        ),
      );

      expect(result.revenuMensuelHorsAvs, greaterThan(0));
      expect(result.revenuMensuelAt65, isNull);
    });

    group('restored non-AVS regression matrix', () {
      test('salaireAssure absent falls back to gross salary', () {
        final profile = buildProfile(
          birthYear: 1990,
          avoirLppTotal: 5000,
          salaireAssure: null,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final result = RetirementProjectionService.project(profile: profile);

        expect(
          result.revenuMensuelHorsAvs,
          closeTo(expectedLppMonthlyFromCore(profile), 0.01),
        );
      });

      test('salaireAssure zero falls back to gross salary', () {
        final profile = buildProfile(
          birthYear: 1990,
          avoirLppTotal: 5000,
          salaireAssure: 0,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final result = RetirementProjectionService.project(profile: profile);

        expect(
          result.revenuMensuelHorsAvs,
          closeTo(expectedLppMonthlyFromCore(profile), 0.01),
        );
      });

      test('salaireAssure below entry threshold adds no bonifications', () {
        final profile = buildProfile(
          birthYear: 1990,
          avoirLppTotal: 5000,
          salaireAssure: lppSeuilEntree - 1,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );
        final fallback = buildProfile(
          birthYear: 1990,
          avoirLppTotal: 5000,
          salaireAssure: null,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final result = RetirementProjectionService.project(profile: profile);

        expect(
          result.revenuMensuelHorsAvs,
          closeTo(expectedLppMonthlyFromCore(profile), 0.01),
        );
        expect(
          result.revenuMensuelHorsAvs,
          lessThan(expectedLppMonthlyFromCore(fallback)),
        );
      });

      test('salary below LPP entry threshold compounds balance only', () {
        final profile = buildProfile(
          birthYear: 1990,
          salaireBrutMensuel: (lppSeuilEntree - 1) / 12,
          avoirLppTotal: 5000,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final result = RetirementProjectionService.project(profile: profile);

        expect(profile.revenuBrutAnnuel, lessThan(lppSeuilEntree));
        expect(
          result.revenuMensuelHorsAvs,
          closeTo(expectedLppMonthlyFromCore(profile), 0.01),
        );
      });

      test('salary at LPP entry threshold applies bonifications', () {
        final atThreshold = buildProfile(
          birthYear: 1990,
          salaireBrutMensuel: lppSeuilEntree / 12,
          avoirLppTotal: 5000,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );
        final belowThreshold = buildProfile(
          birthYear: 1990,
          salaireBrutMensuel: (lppSeuilEntree - 1) / 12,
          avoirLppTotal: 5000,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final result = RetirementProjectionService.project(
          profile: atThreshold,
        );

        expect(atThreshold.revenuBrutAnnuel, lppSeuilEntree);
        expect(
          result.revenuMensuelHorsAvs,
          closeTo(expectedLppMonthlyFromCore(atThreshold), 0.01),
        );
        expect(
          result.revenuMensuelHorsAvs,
          greaterThan(expectedLppMonthlyFromCore(belowThreshold)),
        );
      });

      test('independant without LPP uses the higher 3a ceiling', () {
        CoachProfile profile(String employmentStatus) => buildProfile(
              birthYear: 1985,
              salaireBrutMensuel: (lppSeuilEntree - 1) / 12,
              employmentStatus: employmentStatus,
              avoirLppTotal: 0,
              totalEpargne3a: 0,
              epargneLiquide: 0,
              investissements: 0,
              contributions: [
                const PlannedMonthlyContribution(
                  id: '3a',
                  label: '3a',
                  amount: pilier3aPlafondSansLpp / 12,
                  category: '3a',
                ),
              ],
            );

        final independant = RetirementProjectionService.project(
          profile: profile('independant'),
        );
        final salarie = RetirementProjectionService.project(
          profile: profile('salarie'),
        );

        expect(independant.revenuMensuelHorsAvs,
            greaterThan(salarie.revenuMensuelHorsAvs));
      });

      test('conjoint unable to contribute does not double the 3a ceiling', () {
        CoachProfile profile({required bool conjointCanContribute}) =>
            buildProfile(
              birthYear: 1985,
              salaireBrutMensuel: (lppSeuilEntree - 1) / 12,
              avoirLppTotal: 0,
              totalEpargne3a: 0,
              epargneLiquide: 0,
              investissements: 0,
              etatCivil: CoachCivilStatus.marie,
              conjoint: ConjointProfile(
                birthYear: 1985,
                salaireBrutMensuel: 0,
                prevoyance: PrevoyanceProfile(
                  avoirLppTotal: 0,
                  totalEpargne3a: 0,
                  canContribute3a: conjointCanContribute,
                ),
              ),
              contributions: [
                const PlannedMonthlyContribution(
                  id: '3a_household',
                  label: '3a ménage',
                  amount: pilier3aPlafondAvecLpp * 2 / 12,
                  category: '3a',
                ),
              ],
            );

        final blocked = RetirementProjectionService.project(
          profile: profile(conjointCanContribute: false),
        );
        final eligible = RetirementProjectionService.project(
          profile: profile(conjointCanContribute: true),
        );

        expect(blocked.revenuMensuelHorsAvs,
            lessThan(eligible.revenuMensuelHorsAvs));
      });

      test('default LPP strategy is the explicit rente strategy', () {
        final profile = buildProfile(
          avoirLppTotal: 200000,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final implicit = RetirementProjectionService.project(profile: profile);
        final explicit = RetirementProjectionService.project(
          profile: profile,
          lppCapitalPct: 0,
        );

        expect(implicit.revenuMensuelHorsAvs,
            closeTo(explicit.revenuMensuelHorsAvs, 0.000001));
        expect(implicit.revenuMensuelHorsAvs,
            closeTo(expectedLppMonthlyFromCore(profile), 0.01));
      });

      test('LPP rente income is above mixte, which is above capital', () {
        final profile = buildProfile(
          avoirLppTotal: 200000,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final rente = RetirementProjectionService.project(
          profile: profile,
          lppCapitalPct: 0,
        );
        final mixte = RetirementProjectionService.project(
          profile: profile,
          lppCapitalPct: 0.5,
        );
        final capital = RetirementProjectionService.project(
          profile: profile,
          lppCapitalPct: 1,
        );

        expect(rente.revenuMensuelHorsAvs,
            greaterThan(mixte.revenuMensuelHorsAvs));
        expect(mixte.revenuMensuelHorsAvs,
            greaterThan(capital.revenuMensuelHorsAvs));
        expect(
            mixte.revenuMensuelHorsAvs,
            closeTo(
                expectedLppMonthlyFromCore(profile, lppCapitalPct: 0.5), 0.01));
      });

      test('married capital taxation leaves more income than single', () {
        CoachProfile profile(CoachCivilStatus status) => buildProfile(
              etatCivil: status,
              avoirLppTotal: 200000,
              totalEpargne3a: 0,
              epargneLiquide: 0,
              investissements: 0,
            );
        final marriedProfile = profile(CoachCivilStatus.marie);
        final singleProfile = profile(CoachCivilStatus.celibataire);
        final annualRente = LppCalculator.projectToRetirement(
          currentBalance: marriedProfile.prevoyance.avoirLppTotal ?? 0,
          currentAge: marriedProfile.age,
          retirementAge: avsAgeReferenceHomme,
          grossAnnualSalary: marriedProfile.revenuBrutAnnuel,
          caisseReturn: marriedProfile.prevoyance.rendementCaisse,
          conversionRate: marriedProfile.prevoyance.tauxConversion,
        );
        final projectedBalance =
            annualRente / marriedProfile.prevoyance.tauxConversion;

        final marriedTax = RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: projectedBalance,
          canton: marriedProfile.canton,
          isMarried: true,
        );
        final singleTax = RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: projectedBalance,
          canton: singleProfile.canton,
          isMarried: false,
        );
        final married = RetirementProjectionService.project(
          profile: marriedProfile,
          lppCapitalPct: 1,
        );
        final single = RetirementProjectionService.project(
          profile: singleProfile,
          lppCapitalPct: 1,
        );

        expect(marriedTax, lessThan(singleTax));
        expect(married.revenuMensuelHorsAvs,
            greaterThan(single.revenuMensuelHorsAvs));
        expect(
          single.revenuMensuelHorsAvs,
          closeTo(
            expectedLppMonthlyFromCore(singleProfile, lppCapitalPct: 1),
            0.01,
          ),
        );
      });

      test('conjoint-first age gap does not truncate the household 3a horizon',
          () {
        CoachProfile profile(int conjointBirthYear) => buildProfile(
              birthYear: 1985,
              salaireBrutMensuel: (lppSeuilEntree - 1) / 12,
              avoirLppTotal: 0,
              totalEpargne3a: 30000,
              epargneLiquide: 0,
              investissements: 0,
              etatCivil: CoachCivilStatus.marie,
              conjoint: ConjointProfile(
                birthYear: conjointBirthYear,
                salaireBrutMensuel: 0,
                prevoyance: const PrevoyanceProfile(
                  avoirLppTotal: 0,
                  totalEpargne3a: 10000,
                ),
              ),
              contributions: const [
                PlannedMonthlyContribution(
                  id: '3a_user',
                  label: '3a user',
                  amount: 500,
                  category: '3a',
                ),
              ],
            );
        final conjointFirst = profile(1975);
        final sameAge = profile(1985);

        final conjointFirstResult = RetirementProjectionService.project(
          profile: conjointFirst,
        );
        final sameAgeResult = RetirementProjectionService.project(
          profile: sameAge,
        );

        expect(conjointFirst.conjoint!.age, greaterThan(conjointFirst.age));
        expect(
          conjointFirstResult.revenuMensuelHorsAvs,
          closeTo(sameAgeResult.revenuMensuelHorsAvs, 0.000001),
        );
      });

      test('disclaimer contains no ComplianceGuard banned term', () {
        final result = RetirementProjectionService.project(
          profile: buildProfile(),
        );
        final disclaimer = result.disclaimer.toLowerCase();

        for (final term in ComplianceGuard.bannedTerms) {
          expect(
            disclaimer.contains(term.toLowerCase()),
            isFalse,
            reason: 'Banned term in retirement disclaimer: $term',
          );
        }
      });

      test('concubin couple uses non-married capital taxation', () {
        final profile = buildProfile(
          etatCivil: CoachCivilStatus.concubinage,
          avoirLppTotal: 200000,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
          conjoint: const ConjointProfile(
            birthYear: 1985,
            salaireBrutMensuel: 0,
            prevoyance: PrevoyanceProfile(avoirLppTotal: 0),
          ),
        );

        final result = RetirementProjectionService.project(
          profile: profile,
          lppCapitalPct: 1,
        );

        expect(profile.isCouple, isTrue);
        expect(result.isCouple, isTrue);
        expect(profile.etatCivil, isNot(CoachCivilStatus.marie));
        expect(
          result.revenuMensuelHorsAvs,
          closeTo(
            expectedLppMonthlyFromCore(profile, lppCapitalPct: 1),
            0.01,
          ),
        );
      });

      test('young worker keeps positive non-AVS LPP income', () {
        final profile = buildProfile(
          birthYear: DateTime.now().year - 25,
          salaireBrutMensuel: 5000,
          avoirLppTotal: 0,
          totalEpargne3a: 0,
          epargneLiquide: 0,
          investissements: 0,
        );

        final result = RetirementProjectionService.project(profile: profile);

        expect(result.revenuMensuelHorsAvs, greaterThan(0));
        expect(
          result.revenuMensuelHorsAvs,
          closeTo(expectedLppMonthlyFromCore(profile), 0.01),
        );
      });
    });

    test('disclaimer contains required compliance text', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      expect(result.disclaimer, contains('educative'));
      expect(result.disclaimer, contains('conseil'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources reference LAVS LPP and LIFD articles', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
    });

    test('formatChf keeps Swiss formatting', () {
      expect(RetirementProjectionService.formatChf(1234), contains("1'234"));
      expect(
        RetirementProjectionService.formatChf(1000000),
        contains("1'000'000"),
      );
      expect(RetirementProjectionService.formatChf(-5000), contains('-'));
    });
  });

  group('RetirementProjectionService — data model unit tests', () {
    test('RetirementIncomeSource.annualAmount = monthly * 12', () {
      const source = RetirementIncomeSource(
        id: 'test',
        label: 'Test',
        monthlyAmount: 2500,
        color: Color(0xFF000000),
      );
      expect(source.annualAmount, equals(30000));
    });

    test('RetirementPhase.totalMonthly sums all sources', () {
      const phase = RetirementPhase(
        label: 'Test',
        startYear: 2042,
        sources: [
          RetirementIncomeSource(
              id: 'avs',
              label: 'AVS',
              monthlyAmount: 2000,
              color: Color(0xFF000000)),
          RetirementIncomeSource(
              id: 'lpp',
              label: 'LPP',
              monthlyAmount: 1500,
              color: Color(0xFF000000)),
        ],
      );
      expect(phase.totalMonthly, equals(3500));
    });
  });
}
