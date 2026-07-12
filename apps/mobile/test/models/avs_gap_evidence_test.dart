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
      expect(evidence.householdReady, isFalse);
      expect(evidence.missingFieldPaths, [selfPath]);
      expect(
        () => evidence.missingFieldPaths.add('another.path'),
        throwsUnsupportedError,
      );
    });

    test('declared noGaps never becomes certified zero', () {
      final evidence = profile(
        declaredStatus: AvsGapStatus.noGaps,
      ).avsGapEvidence;

      expect(evidence.declaredStatus, AvsGapStatus.noGaps);
      expect(evidence.selfCertifiedYears, isNull);
      expect(evidence.selfReady, isFalse);
      expect(evidence.householdReady, isFalse);
      expect(evidence.missingFieldPaths, [selfPath]);
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
      expect(evidence.householdReady, isTrue);
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

    test('real spouse in a couple is required and missing fail-closed', () {
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
      expect(evidence.householdReady, isFalse);
      expect(evidence.missingFieldPaths, [spousePath]);
    });

    test('couple is ready only when both persons are certificate-backed', () {
      final evidence = profile(
        selfYears: 0,
        civilStatus: CoachCivilStatus.concubinage,
        spouse: const ConjointProfile(
          prevoyance: PrevoyanceProfile(lacunesAVS: 3),
        ),
        dataSources: const {
          selfPath: ProfileDataSource.certificate,
          spousePath: ProfileDataSource.certificate,
        },
      ).avsGapEvidence;

      expect(evidence.selfCertifiedYears, 0);
      expect(evidence.spouseCertifiedYears, 3);
      expect(evidence.spouseRequired, isTrue);
      expect(evidence.selfReady, isTrue);
      expect(evidence.householdReady, isTrue);
      expect(evidence.missingFieldPaths, isEmpty);
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
      expect(evidence.householdReady, isTrue);
      expect(evidence.missingFieldPaths, isEmpty);
    });

    test('declared couple without a real spouse does not require spouse facts',
        () {
      final evidence = profile(
        selfYears: 0,
        civilStatus: CoachCivilStatus.marie,
        dataSources: const {
          selfPath: ProfileDataSource.certificate,
        },
      ).avsGapEvidence;

      expect(evidence.spouseRequired, isFalse);
      expect(evidence.householdReady, isTrue);
      expect(evidence.missingFieldPaths, isEmpty);
    });
  });
}
