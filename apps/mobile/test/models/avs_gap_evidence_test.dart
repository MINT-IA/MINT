import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  const selfPath = 'prevoyance.lacunesAVS';
  const spousePath = 'conjoint.prevoyance.lacunesAVS';

  CoachProfile profile({
    int? selfYears,
    AvsGapStatus? declaredStatus,
    CoachCivilStatus civilStatus = CoachCivilStatus.celibataire,
    ConjointProfile? spouse,
    Map<String, ProfileDataSource> dataSources = const {},
  }) {
    return CoachProfile(
      birthYear: 1990,
      canton: 'VD',
      salaireBrutMensuel: 7000,
      etatCivil: civilStatus,
      conjoint: spouse,
      avsGapStatus: declaredStatus,
      prevoyance: PrevoyanceProfile(lacunesAVS: selfYears),
      dataSources: dataSources,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055),
        label: 'Retraite',
      ),
    );
  }

  group('CoachProfile.avsGapEvidence', () {
    test('missing self years are explicit and immutable', () {
      final evidence = profile().avsGapEvidence;

      expect(evidence.selfCertifiedYears, isNull);
      expect(evidence.spouseCertifiedYears, isNull);
      expect(evidence.spouseRequired, isFalse);
      expect(evidence.declaredStatus, isNull);
      expect(evidence.selfReady, isFalse);
      expect(evidence.householdTotalReady, isFalse);
      expect(evidence.householdReady, isFalse);
      expect(evidence.maritalCapApplicable, isFalse);
      expect(evidence.maritalCapReady, isFalse);
      expect(evidence.missingFieldPaths, [selfPath]);
      expect(
        () => evidence.missingFieldPaths.add('another.path'),
        throwsUnsupportedError,
      );
    });

    test('all declared statuses remain uncertified without CI evidence', () {
      for (final status in AvsGapStatus.values) {
        final evidence = profile(declaredStatus: status).avsGapEvidence;

        expect(evidence.declaredStatus, status);
        expect(evidence.selfCertifiedYears, isNull, reason: status.name);
        expect(evidence.selfReady, isFalse, reason: status.name);
        expect(evidence.householdTotalReady, isFalse, reason: status.name);
        expect(evidence.householdReady, isFalse, reason: status.name);
        expect(evidence.missingFieldPaths, [selfPath], reason: status.name);
      }
    });

    test('numeric self years without certificate provenance are not ready', () {
      final evidence = profile(selfYears: 0).avsGapEvidence;

      expect(evidence.selfCertifiedYears, isNull);
      expect(evidence.selfReady, isFalse);
      expect(evidence.missingFieldPaths, [selfPath]);
    });

    test('certificate-backed zero is a ready self fact', () {
      final evidence = profile(
        selfYears: 0,
        dataSources: const {
          selfPath: ProfileDataSource.certificate,
        },
      ).avsGapEvidence;

      expect(evidence.selfCertifiedYears, 0);
      expect(evidence.selfReady, isTrue);
      expect(evidence.householdTotalReady, isTrue);
      expect(evidence.householdReady, isTrue);
      expect(evidence.maritalCapApplicable, isFalse);
      expect(evidence.maritalCapReady, isFalse);
      expect(evidence.missingFieldPaths, isEmpty);
    });

    test('certificate-backed positive years are a ready self fact', () {
      final evidence = profile(
        selfYears: 4,
        dataSources: const {
          selfPath: ProfileDataSource.certificate,
        },
      ).avsGapEvidence;

      expect(evidence.selfCertifiedYears, 4);
      expect(evidence.selfReady, isTrue);
      expect(evidence.householdReady, isTrue);
      expect(evidence.missingFieldPaths, isEmpty);
    });

    test('present spouse without CI evidence keeps household incomplete', () {
      final evidence = profile(
        selfYears: 0,
        civilStatus: CoachCivilStatus.marie,
        spouse: const ConjointProfile(
          prevoyance: PrevoyanceProfile(),
        ),
        dataSources: const {
          selfPath: ProfileDataSource.certificate,
        },
      ).avsGapEvidence;

      expect(evidence.selfCertifiedYears, 0);
      expect(evidence.spouseCertifiedYears, isNull);
      expect(evidence.spouseRequired, isTrue);
      expect(evidence.selfReady, isTrue);
      expect(evidence.householdTotalReady, isFalse);
      expect(evidence.householdReady, isFalse);
      expect(evidence.maritalCapApplicable, isTrue);
      expect(evidence.maritalCapReady, isFalse);
      expect(evidence.missingFieldPaths, [spousePath]);
    });

    test('marriage-equivalent household is ready with two certified zeros', () {
      for (final civilStatus in const [
        CoachCivilStatus.marie,
        CoachCivilStatus.registeredPartnership,
      ]) {
        final evidence = profile(
          selfYears: 0,
          civilStatus: civilStatus,
          spouse: const ConjointProfile(
            prevoyance: PrevoyanceProfile(lacunesAVS: 0),
          ),
          dataSources: const {
            selfPath: ProfileDataSource.certificate,
            spousePath: ProfileDataSource.certificate,
          },
        ).avsGapEvidence;

        expect(evidence.selfCertifiedYears, 0, reason: civilStatus.name);
        expect(evidence.spouseCertifiedYears, 0, reason: civilStatus.name);
        expect(evidence.selfReady, isTrue, reason: civilStatus.name);
        expect(evidence.householdTotalReady, isTrue, reason: civilStatus.name);
        expect(evidence.householdReady, isTrue, reason: civilStatus.name);
        expect(evidence.maritalCapApplicable, isTrue, reason: civilStatus.name);
        expect(evidence.maritalCapReady, isTrue, reason: civilStatus.name);
        expect(evidence.missingFieldPaths, isEmpty, reason: civilStatus.name);
      }
    });

    test('single profile never requires spouse evidence', () {
      final evidence = profile(
        selfYears: 0,
        civilStatus: CoachCivilStatus.celibataire,
        spouse: const ConjointProfile(
          prevoyance: PrevoyanceProfile(lacunesAVS: 8),
        ),
        dataSources: const {
          selfPath: ProfileDataSource.certificate,
        },
      ).avsGapEvidence;

      expect(evidence.spouseRequired, isFalse);
      expect(evidence.householdTotalReady, isTrue);
      expect(evidence.householdReady, isTrue);
      expect(evidence.maritalCapApplicable, isFalse);
      expect(evidence.maritalCapReady, isFalse);
      expect(evidence.missingFieldPaths, isEmpty);
    });

    test('marriage-equivalent status requires spouse facts without object', () {
      for (final civilStatus in const [
        CoachCivilStatus.marie,
        CoachCivilStatus.registeredPartnership,
      ]) {
        final evidence = profile(
          selfYears: 0,
          civilStatus: civilStatus,
          dataSources: const {
            selfPath: ProfileDataSource.certificate,
          },
        ).avsGapEvidence;

        expect(evidence.spouseRequired, isTrue, reason: civilStatus.name);
        expect(evidence.selfReady, isTrue, reason: civilStatus.name);
        expect(evidence.householdTotalReady, isFalse, reason: civilStatus.name);
        expect(evidence.householdReady, isFalse, reason: civilStatus.name);
        expect(evidence.maritalCapApplicable, isTrue, reason: civilStatus.name);
        expect(evidence.maritalCapReady, isFalse, reason: civilStatus.name);
        expect(evidence.missingFieldPaths, [spousePath],
            reason: civilStatus.name);
      }
    });

    test('cohabiting self-only evidence keeps household and cap separate', () {
      final evidence = profile(
        selfYears: 0,
        civilStatus: CoachCivilStatus.concubinage,
        dataSources: const {
          selfPath: ProfileDataSource.certificate,
        },
      ).avsGapEvidence;

      expect(evidence.selfReady, isTrue);
      expect(evidence.householdTotalReady, isFalse);
      expect(evidence.householdReady, isFalse);
      expect(evidence.maritalCapApplicable, isFalse);
      expect(evidence.maritalCapReady, isFalse);
      expect(evidence.missingFieldPaths, [spousePath]);
    });
  });
}
