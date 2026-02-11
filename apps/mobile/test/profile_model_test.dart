import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/profile.dart';

void main() {
  // ────────────────────────────────────────────────────────────
  // GROUP 4: Profile model tests
  // ────────────────────────────────────────────────────────────
  group('Profile model', () {
    final sampleJson = {
      'id': 'profile-123',
      'birthYear': 1990,
      'canton': 'VD',
      'householdType': 'couple',
      'incomeNetMonthly': 6500.0,
      'incomeGrossYearly': 95000.0,
      'savingsMonthly': 800.0,
      'totalSavings': 45000.0,
      'lppInsuredSalary': 60000.0,
      'hasDebt': false,
      'factfindCompletionIndex': 0.75,
      'goal': 'house',
      'createdAt': '2025-06-15T10:30:00.000Z',
      'employmentStatus': 'self_employed',
      'has2ndPillar': false,
      'legalForm': 'raison_individuelle',
      'selfEmployedNetIncome': 90000.0,
      'hasVoluntaryLpp': false,
      'primaryActivity': null,
      'hasAvsGaps': true,
      'avsContributionYears': 20,
      'spouseAvsContributionYears': 18,
      'commune': 'Lausanne',
      'isChurchMember': true,
      'pillar3aAnnual': 7258.0,
    };

    test('Profile.fromJson creates correctly', () {
      final profile = Profile.fromJson(sampleJson);

      expect(profile.id, 'profile-123');
      expect(profile.birthYear, 1990);
      expect(profile.canton, 'VD');
      expect(profile.householdType, HouseholdType.couple);
      expect(profile.incomeNetMonthly, 6500.0);
      expect(profile.incomeGrossYearly, 95000.0);
      expect(profile.savingsMonthly, 800.0);
      expect(profile.totalSavings, 45000.0);
      expect(profile.lppInsuredSalary, 60000.0);
      expect(profile.hasDebt, false);
      expect(profile.factfindCompletionIndex, 0.75);
      expect(profile.goal, Goal.house);
      expect(profile.createdAt, DateTime.parse('2025-06-15T10:30:00.000Z'));
      expect(profile.employmentStatus, EmploymentStatus.selfEmployed);
      expect(profile.has2ndPillar, false);
      expect(profile.legalForm, 'raison_individuelle');
      expect(profile.selfEmployedNetIncome, 90000.0);
      expect(profile.hasVoluntaryLpp, false);
      expect(profile.hasAvsGaps, true);
      expect(profile.avsContributionYears, 20);
      expect(profile.spouseAvsContributionYears, 18);
      expect(profile.commune, 'Lausanne');
      expect(profile.isChurchMember, true);
      expect(profile.pillar3aAnnual, 7258.0);
    });

    test('Profile.toJson roundtrips', () {
      final profile = Profile.fromJson(sampleJson);
      final json = profile.toJson();

      // Re-parse and verify key fields survive the roundtrip
      final roundtripped = Profile.fromJson(json);

      expect(roundtripped.id, profile.id);
      expect(roundtripped.birthYear, profile.birthYear);
      expect(roundtripped.canton, profile.canton);
      expect(roundtripped.householdType, profile.householdType);
      expect(roundtripped.incomeNetMonthly, profile.incomeNetMonthly);
      expect(roundtripped.incomeGrossYearly, profile.incomeGrossYearly);
      expect(roundtripped.savingsMonthly, profile.savingsMonthly);
      expect(roundtripped.totalSavings, profile.totalSavings);
      expect(roundtripped.lppInsuredSalary, profile.lppInsuredSalary);
      expect(roundtripped.hasDebt, profile.hasDebt);
      expect(roundtripped.factfindCompletionIndex,
          profile.factfindCompletionIndex);
      expect(roundtripped.goal, profile.goal);
      expect(roundtripped.createdAt, profile.createdAt);
      expect(roundtripped.employmentStatus, profile.employmentStatus);
      expect(roundtripped.has2ndPillar, profile.has2ndPillar);
      expect(roundtripped.legalForm, profile.legalForm);
      expect(
          roundtripped.selfEmployedNetIncome, profile.selfEmployedNetIncome);
      expect(roundtripped.hasVoluntaryLpp, profile.hasVoluntaryLpp);
      expect(roundtripped.hasAvsGaps, profile.hasAvsGaps);
      expect(
          roundtripped.avsContributionYears, profile.avsContributionYears);
      expect(roundtripped.spouseAvsContributionYears,
          profile.spouseAvsContributionYears);
      expect(roundtripped.commune, profile.commune);
      expect(roundtripped.isChurchMember, profile.isChurchMember);
      expect(roundtripped.pillar3aAnnual, profile.pillar3aAnnual);
    });

    test('Profile.copyWith preserves unchanged fields', () {
      final original = Profile.fromJson(sampleJson);
      final modified = original.copyWith(canton: 'GE');

      // Changed field
      expect(modified.canton, 'GE');

      // All other fields should be preserved
      expect(modified.id, original.id);
      expect(modified.birthYear, original.birthYear);
      expect(modified.householdType, original.householdType);
      expect(modified.incomeNetMonthly, original.incomeNetMonthly);
      expect(modified.incomeGrossYearly, original.incomeGrossYearly);
      expect(modified.savingsMonthly, original.savingsMonthly);
      expect(modified.totalSavings, original.totalSavings);
      expect(modified.lppInsuredSalary, original.lppInsuredSalary);
      expect(modified.hasDebt, original.hasDebt);
      expect(modified.factfindCompletionIndex,
          original.factfindCompletionIndex);
      expect(modified.goal, original.goal);
      expect(modified.createdAt, original.createdAt);
      expect(modified.employmentStatus, original.employmentStatus);
      expect(modified.has2ndPillar, original.has2ndPillar);
      expect(modified.legalForm, original.legalForm);
      expect(modified.selfEmployedNetIncome, original.selfEmployedNetIncome);
      expect(modified.hasVoluntaryLpp, original.hasVoluntaryLpp);
      expect(modified.hasAvsGaps, original.hasAvsGaps);
      expect(modified.avsContributionYears, original.avsContributionYears);
      expect(modified.spouseAvsContributionYears,
          original.spouseAvsContributionYears);
      expect(modified.commune, original.commune);
      expect(modified.isChurchMember, original.isChurchMember);
      expect(modified.pillar3aAnnual, original.pillar3aAnnual);
    });

    test('Profile.hasDebt defaults to false', () {
      final minimalJson = {
        'id': 'profile-minimal',
        'householdType': 'single',
        'goal': 'other',
        'createdAt': '2025-01-01T00:00:00.000Z',
        // hasDebt not specified
      };

      final profile = Profile.fromJson(minimalJson);
      expect(profile.hasDebt, false);
    });

    test('Profile.needsProtectionCoverage for independent without LPP', () {
      final profileSelfEmployedNoLpp = Profile(
        id: 'test-1',
        householdType: HouseholdType.single,
        goal: Goal.other,
        createdAt: DateTime(2025, 1, 1),
        employmentStatus: EmploymentStatus.selfEmployed,
        has2ndPillar: false,
      );
      expect(profileSelfEmployedNoLpp.needsProtectionCoverage, true);

      // Self-employed WITH LPP should NOT need protection coverage
      final profileSelfEmployedWithLpp = Profile(
        id: 'test-2',
        householdType: HouseholdType.single,
        goal: Goal.other,
        createdAt: DateTime(2025, 1, 1),
        employmentStatus: EmploymentStatus.selfEmployed,
        has2ndPillar: true,
      );
      expect(profileSelfEmployedWithLpp.needsProtectionCoverage, false);

      // Mixed without LPP should also need protection coverage
      final profileMixedNoLpp = Profile(
        id: 'test-3',
        householdType: HouseholdType.single,
        goal: Goal.other,
        createdAt: DateTime(2025, 1, 1),
        employmentStatus: EmploymentStatus.mixed,
        has2ndPillar: false,
      );
      expect(profileMixedNoLpp.needsProtectionCoverage, true);

      // Regular employee should NOT need protection coverage
      final profileEmployee = Profile(
        id: 'test-4',
        householdType: HouseholdType.single,
        goal: Goal.other,
        createdAt: DateTime(2025, 1, 1),
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
      );
      expect(profileEmployee.needsProtectionCoverage, false);
    });
  });

  group('EmploymentStatus', () {
    test('EmploymentStatus.value returns correct strings', () {
      expect(EmploymentStatus.employee.value, 'employee');
      expect(EmploymentStatus.selfEmployed.value, 'self_employed');
      expect(EmploymentStatus.mixed.value, 'mixed');
      expect(EmploymentStatus.student.value, 'student');
      expect(EmploymentStatus.retired.value, 'retired');
      expect(EmploymentStatus.other.value, 'other');
    });
  });
}
